#!/usr/bin/env bash
# Config contract of the version line 1: the PHP image runs a PHP release
# with the fix of CVE-2026-109618 and CVE-2026-109619, keeps the hardening of
# mwaeckerlin/php-fpm, and declares the data volume of the old image.
#
#   - PHP is at least 8.5.12 on the line 8.5 and at least 8.4.27 on the line
#     8.4, the first releases with the fix; a later minor line passes
#   - session upload progress is off and locked in the pool, and the pool
#     locks fatal error backtraces off, the mitigations named with the leaked
#     details of both CVEs
#   - /app/data is a declared volume
#
# Usage: tests/config-contract.sh IMAGE

set -uo pipefail

# the last argument, so `npm test -- <image>` measures another image
IMAGE="${!#}"
PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

echo "==> Config contract: ${IMAGE}"

VERSION_LINE=$(docker run --rm --pull=never "${IMAGE}" -v 2>&1 | head -n 1)
echo "        PHP in the image: ${VERSION_LINE}"

# the releases that fix CVE-2026-109618 and CVE-2026-109619
_patched() {
    local major minor patch
    if [[ ! "$1" =~ ^PHP\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        return 1
    fi
    major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
    if (( major > 8 || (major == 8 && minor > 5) )); then
        return 0
    fi
    (( major == 8 && minor == 5 && patch >= 12 )) && return 0
    (( major == 8 && minor == 4 && patch >= 27 )) && return 0
    return 1
}
if _patched "${VERSION_LINE}"; then
    _pass "php_patched_release"
else
    _fail "php_patched_release" "${VERSION_LINE:-no version reported} is older than 8.5.12 and 8.4.27"
fi
# the comparison itself, at both sides of each limit
SELFTEST=""
for line in "PHP 8.5.12 (fpm-fcgi)" "PHP 8.4.27 (fpm-fcgi)" "PHP 8.6.0 (fpm-fcgi)" "PHP 9.0.0 (fpm-fcgi)"; do
    _patched "${line}" || SELFTEST="${SELFTEST} '${line}' refused;"
done
for line in "PHP 8.5.11 (fpm-fcgi)" "PHP 8.4.26 (fpm-fcgi)" "PHP 8.4.21 (fpm-fcgi)" "PHP 8.3.99 (fpm-fcgi)" "no php"; do
    _patched "${line}" && SELFTEST="${SELFTEST} '${line}' accepted;"
done
if [[ -z "${SELFTEST}" ]]; then
    _pass "selftest_patched_release_limits"
else
    _fail "selftest_patched_release_limits" "${SELFTEST}"
fi

INFO=$(docker run --rm --pull=never "${IMAGE}" -i 2>&1)
if grep -Eiq 'session\.upload_progress\.enabled( => |</td><td class="v">)(Off|0)' <<<"${INFO}"; then
    _pass "session_upload_progress_off"
else
    _fail "session_upload_progress_off" "$(grep -i 'session.upload_progress.enabled' <<<"${INFO}" || echo 'setting not reported')"
fi
CONFIG=$(docker run --rm --pull=never "${IMAGE}" -tt 2>&1)
if grep -Eq 'session\.upload_progress\.enabled\] = (off|no|0)' <<<"${CONFIG}"; then
    _pass "session_upload_progress_locked"
else
    _fail "session_upload_progress_locked" "the pool does not lock session.upload_progress.enabled off"
fi
if grep -Eq 'fatal_error_backtraces\] = (off|no|0)' <<<"${CONFIG}"; then
    _pass "fatal_error_backtraces_locked"
else
    _fail "fatal_error_backtraces_locked" "the pool does not lock fatal_error_backtraces off"
fi

VOLUMES=$(docker image inspect --format '{{json .Config.Volumes}}' "${IMAGE}" 2>&1)
if [[ "${VOLUMES}" == *'"/app/data"'* ]]; then
    _pass "volume__app_data"
else
    _fail "volume__app_data" "declared volumes: ${VOLUMES}"
fi

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
