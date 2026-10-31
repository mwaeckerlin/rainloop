#!/usr/bin/env bash
# End-to-end test of the version line 1: both images run as the compose file
# wires them, the nginx image in front of the php-fpm image reachable under
# its service name `snappymail`, the data volume on /app/data, and a client
# in the same network requests the webmail through nginx.
#
#   - the start page is rendered by PHP and links the static files of the
#     installed SnappyMail release, which nginx serves
#   - the admin page is rendered by PHP as well, and the data it loads
#     answers without a login
#   - what SnappyMail writes on the first requests, the configuration and the
#     generated admin password, lies in the volume, and a new php-fpm
#     container on the same volume finds it
#
# Usage: tests/e2e.sh PHP_IMAGE NGINX_IMAGE

set -uo pipefail

PHP_IMAGE="$1"
NGINX_IMAGE="$2"
RUN="rainloop-e2e-$$"
NETWORK="${RUN}"
VOLUME="${RUN}-data"
PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

_cleanup() {
    docker rm -f "${RUN}-php" "${RUN}-nginx" > /dev/null 2>&1
    docker network rm "${NETWORK}" > /dev/null 2>&1
    docker volume rm -f "${VOLUME}" > /dev/null 2>&1
}
trap _cleanup EXIT

_result() {
    echo ""
    echo "==> End-to-end results: ${PASS} passed, ${FAIL} failed"
    if [[ ${FAIL} -gt 0 ]]; then
        echo "==> Failed checks: ${FAILED_NAMES[*]}"
        exit 1
    fi
    exit 0
}

# PHP of the php-fpm image as the client: it is in the image under test and
# needs no foreign image; the arguments are the URL and the expected status
_get() {
    docker run --rm --pull=never --network "${NETWORK}" --entrypoint /usr/bin/php "${PHP_IMAGE}" -r '
        $context = stream_context_create(["http" => ["ignore_errors" => true, "timeout" => 30]]);
        $body = @file_get_contents($argv[1], false, $context);
        $headers = http_get_last_response_headers() ?? [];
        $status = isset($headers[0]) ? explode(" ", $headers[0])[1] : "none";
        if ($status !== $argv[2]) { fwrite(STDERR, "status " . $status . "\n"); exit(1); }
        echo $body;' "$1" "$2"
}

# runs PHP code in a new php-fpm container on the data volume
_in_volume() {
    docker run --rm --pull=never --network none -v "${VOLUME}:/app/data" --entrypoint /usr/bin/php "${PHP_IMAGE}" -r "$1"
}

echo "==> End-to-end: ${NGINX_IMAGE} in front of ${PHP_IMAGE}"

docker network create "${NETWORK}" > /dev/null
docker volume create "${VOLUME}" > /dev/null
if ! docker run -d --pull=never --name "${RUN}-php" --network "${NETWORK}" --network-alias snappymail \
        -v "${VOLUME}:/app/data" "${PHP_IMAGE}" > /dev/null; then
    _fail "php_fpm_starts" "the container did not start"
    _result
fi
if ! docker run -d --pull=never --name "${RUN}-nginx" --network "${NETWORK}" --network-alias proxy \
        "${NGINX_IMAGE}" > /dev/null; then
    _fail "nginx_starts" "the container did not start"
    _result
fi

# no container reports that it accepts requests, so the start page is asked
# again until php-fpm answers through nginx: at most 60 times one second,
# which is long enough for a loaded runner, and a stack that does not answer
# fails within a minute
START=""
for _ in $(seq 60); do
    if START=$(_get http://proxy:8080/ 200 2> /dev/null); then
        break
    fi
    START=""
    sleep 1
done

if [[ "${START}" == *"<html"* && "${START}" != *"<?php"* ]]; then
    _pass "start_page_rendered_by_php"
else
    _fail "start_page_rendered_by_php" "no rendered page: $(docker logs "${RUN}-nginx" 2>&1 | tail -n 5)"
fi

ASSET=$(grep -oE 'snappymail/v/[^"?]+/static/css/app\.min\.css' <<< "${START}" | head -n 1)
CSS=""
[[ -n "${ASSET}" ]] && CSS=$(_get "http://proxy:8080/${ASSET}" 200)
if [[ -n "${CSS}" && "${CSS}" != *"<html"* ]]; then
    _pass "static_file_of_the_release_served"
else
    _fail "static_file_of_the_release_served" "the stylesheet of the release is not served: '${ASSET}'"
fi

ADMIN=$(_get "http://proxy:8080/?admin" 200)
if [[ "${ADMIN}" == *"<html"* && "${ADMIN}" != *"<?php"* ]]; then
    _pass "admin_page_rendered_by_php"
else
    _fail "admin_page_rendered_by_php" "the admin page answers no rendered page"
fi

# the admin page loads its data from this address, the request in which
# SnappyMail creates the admin password while none is set
ADMIN_DATA=$(_get "http://proxy:8080/?/AdminAppData/0/1/" 200)
if [[ "${ADMIN_DATA}" == "{"* && "${ADMIN_DATA}" == *'"Auth":false'* ]]; then
    _pass "admin_data_answered_without_login"
else
    _fail "admin_data_answered_without_login" "no admin data without login: ${ADMIN_DATA:0:200}"
fi

if _in_volume 'exit(is_file("/app/data/_data_/_default_/configs/application.ini") ? 0 : 1);'; then
    _pass "configuration_written_to_the_volume"
else
    _fail "configuration_written_to_the_volume" "no application.ini in the volume"
fi

if _in_volume 'exit(strlen(trim((string) @file_get_contents("/app/data/_data_/_default_/admin_password.txt"))) >= 8 ? 0 : 1);'; then
    _pass "admin_password_generated_in_the_volume"
else
    _fail "admin_password_generated_in_the_volume" "no admin_password.txt of at least 8 characters in the volume"
fi

_result
