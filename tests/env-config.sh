#!/usr/bin/env bash
# Environment contract: the operator settings of the webmail reach the
# SnappyMail configuration in the data volume — nothing is written while
# a variable is unset, the operator's value when it is set.
#
# The plugin-init image (Dockerfile.plugin-init) runs against a fresh
# named volume, exactly as the compose stacks run it before the webmail
# starts. The test then reads application.ini and the domain file from
# the volume and checks the stored admin password with PHP's
# password_verify() in the php-fpm image, the way SnappyMail checks it.
#
# Usage: tests/env-config.sh

set -uo pipefail

cd "$(dirname "$0")/.."

INIT_IMAGE="mwaeckerlin/snappymail:plugin-init"
PHP_IMAGE="mwaeckerlin/snappymail:php-fpm"
DEFAULT_DIR="/app/data/_data_/_default_"

PASS=0
FAIL=0
declare -a FAILED_NAMES
declare -a VOLUMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

_cleanup() {
    [[ ${#VOLUMES[@]} -gt 0 ]] && docker volume rm -f "${VOLUMES[@]}" > /dev/null 2>&1
}
trap _cleanup EXIT

_new_volume() {
    VOLUME=$(docker volume create)
    VOLUMES+=("${VOLUME}")
}

# Run the init container against VOLUME with the given docker arguments.
_init() {
    INIT_OUT=$(docker run --rm --pull=never --network none \
                   -v "${VOLUME}:/app/data" "$@" "${INIT_IMAGE}" 2>&1)
}

_read() {
    docker run --rm --pull=never --network none -v "${VOLUME}:/app/data:ro" \
        --entrypoint cat "${INIT_IMAGE}" "${DEFAULT_DIR}/$1" 2>/dev/null
}

_expect_line() {
    local name="$1" file="$2" want="$3"
    # grep reads the whole file: grep -q stops at the first match, cat then dies on SIGPIPE and pipefail fails the check
    local content
    content=$(_read "${file}")
    if grep -qxF "${want}" <<<"${content}"; then
        _pass "${name}"
    else
        _fail "${name}" "no line '${want}' in ${file}: $(_read "${file}")"
    fi
}

_expect_count() {
    local name="$1" file="$2" pattern="$3" want="$4" got
    got=$(_read "${file}" | grep -cE "${pattern}")
    if [[ "${got}" == "${want}" ]]; then
        _pass "${name}"
    else
        _fail "${name}" "${got} lines /${pattern}/ in ${file}, expected ${want}: $(_read "${file}")"
    fi
}

_expect_password() {
    local name="$1" password="$2"
    if docker run --rm --pull=never --network none -v "${VOLUME}:/app/data:ro" \
           -e CHECK_PASSWORD="${password}" --entrypoint /usr/bin/php "${PHP_IMAGE}" \
           -r '$ini = parse_ini_file("/app/data/_data_/_default_/configs/application.ini", true);
               exit(password_verify(getenv("CHECK_PASSWORD"), $ini["security"]["admin_password"] ?? "") ? 0 : 1);'; then
        _pass "${name}"
    else
        _fail "${name}" "admin_password does not verify: $(_read configs/application.ini)"
    fi
}

_reject() {
    local name="$1" var="$2" value="$3"
    _new_volume
    _init -e "${var}=${value}"
    if [[ "${INIT_OUT}" == *"invalid ${var}"* ]]; then
        _pass "reject_${name}"
    else
        _fail "reject_${name}" "value not rejected: ${INIT_OUT}"
    fi
}

echo "==> Environment contract: webmail settings reach the data volume"

if ! out=$(docker build -q -f Dockerfile.plugin-init -t "${INIT_IMAGE}" . 2>&1); then
    _fail "init_image_builds" "${out}"
    echo ""; echo "==> Environment contract results: ${PASS} passed, ${FAIL} failed"; exit 1
fi
if ! docker image inspect "${PHP_IMAGE}" > /dev/null 2>&1; then
    _fail "php_image_exists" "image not built — run 'npm run build' first"
    echo ""; echo "==> Environment contract results: ${PASS} passed, ${FAIL} failed"; exit 1
fi

# Unset: the plugin is enabled as before, and nothing else is written.
_new_volume
_init
_expect_count default_no_admin_password configs/application.ini '^admin_password' 0
_expect_line  default_plugin_enabled    configs/application.ini 'enabled_list = "transport-security"'
if docker run --rm --pull=never --network none -v "${VOLUME}:/app/data:ro" \
       --entrypoint test "${INIT_IMAGE}" -e "${DEFAULT_DIR}/domains"; then
    _fail "default_no_domain" "a domains directory was written without DOMAIN"
else
    _pass "default_no_domain"
fi

# Set: password and domain servers are written; a second start with a
# new password replaces the first instead of adding a line.
_new_volume
_init -e SNAPPYMAIL_ADMIN_PASSWORD='first Pw!' -e DOMAIN=example.com
_init -e SNAPPYMAIL_ADMIN_PASSWORD='s3cret Pw!' \
      -e DOMAIN=example.com \
      -e IMAP_HOST=dovecot -e IMAP_PORT=993 -e IMAP_SECURE=SSL \
      -e SMTP_HOST=postfix -e SMTP_PORT=587 -e SMTP_SECURE=TLS
_expect_password override_admin_password 's3cret Pw!'
_expect_count override_one_admin_password configs/application.ini '^admin_password' 1
_expect_count override_plugin_kept configs/application.ini '^enabled_list = "transport-security"$' 1
_expect_line override_imap_host   domains/example.com.ini 'imap_host = "dovecot"'
_expect_line override_imap_port   domains/example.com.ini 'imap_port = "993"'
_expect_line override_imap_secure domains/example.com.ini 'imap_secure = "SSL"'
_expect_line override_smtp_host   domains/example.com.ini 'smtp_host = "postfix"'
_expect_line override_smtp_port   domains/example.com.ini 'smtp_port = "587"'
_expect_line override_smtp_secure domains/example.com.ini 'smtp_secure = "TLS"'

# A key that is not set stays as the admin interface left it.
_init -e DOMAIN=example.com -e IMAP_PORT=143
_expect_line partial_imap_port_replaced domains/example.com.ini 'imap_port = "143"'
_expect_line partial_smtp_host_kept     domains/example.com.ini 'smtp_host = "postfix"'
_expect_password partial_password_kept 's3cret Pw!'

_reject domain_traversal DOMAIN      "../../etc"
_reject imap_host_quote  IMAP_HOST   'dovecot"; x = "y'
_reject smtp_port_range  SMTP_PORT   "70000"
_reject imap_secure_bad  IMAP_SECURE "STARTTLS"
_reject password_newline SNAPPYMAIL_ADMIN_PASSWORD $'pw\nadmin_login = "evil"'

echo ""
echo "==> Environment contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed checks: ${FAILED_NAMES[*]}"
    exit 1
fi
