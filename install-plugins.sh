#!/bin/sh
# Sync the bundled SnappyMail plugin(s) into the data volume and enable
# them in application.ini, then apply the operator settings from the
# environment. Idempotent — safe to run on every start.
#
# SNAPPYMAIL_DATA  data dir (default /app/data), where SnappyMail keeps
#                  _data_/_default_/{plugins,configs,domains}
# SM_DATA_UID      uid that owns the data (default 100, the snappymail
#                  runtime user)
#
# Each of the following is written only when it is set; unset leaves
# the data volume as it is:
#
# SNAPPYMAIL_ADMIN_PASSWORD  admin password, stored as a bcrypt hash in
#                            application.ini [security] admin_password
# DOMAIN                     mail domain whose server settings follow,
#                            domains/<DOMAIN>.ini
# IMAP_HOST, IMAP_PORT, IMAP_SECURE  IMAP server of DOMAIN
# SMTP_HOST, SMTP_PORT, SMTP_SECURE  SMTP server of DOMAIN
#                            (*_SECURE: None, SSL or TLS)
set -eu

DATA="${SNAPPYMAIL_DATA:-/app/data}"
UID_OWNER="${SM_DATA_UID:-100}"
DEFAULT="${DATA}/_data_/_default_"
PLUGINS="${DEFAULT}/plugins"
CONFIGS="${DEFAULT}/configs"
DOMAINS="${DEFAULT}/domains"
CFG="${CONFIGS}/application.ini"

die_invalid() {
    echo "**** ERROR: invalid $1 — refusing to start" >&2
    exit 1
}

# check VAR PATTERN: the value of VAR, when set, matches the shell pattern
# of forbidden characters nowhere.
check() {
    eval "value=\${$1:-}"
    case "${value}" in
        *$2*) die_invalid "$1" ;;
    esac
}

check_port() {
    eval "value=\${$1:-}"
    [ -z "${value}" ] && return 0
    case "${value}" in
        *[!0-9]*) die_invalid "$1" ;;
    esac
    [ "${value}" -ge 1 ] && [ "${value}" -le 65535 ] || die_invalid "$1"
}

check_secure() {
    eval "value=\${$1:-}"
    case "${value}" in
        ""|None|SSL|TLS) ;;
        *) die_invalid "$1" ;;
    esac
}

# A secret is never echoed: only the variable name is reported.
case "${SNAPPYMAIL_ADMIN_PASSWORD:-}" in
    *"
"*) die_invalid SNAPPYMAIL_ADMIN_PASSWORD ;;
esac
check DOMAIN    '[!A-Za-z0-9.-]'
check IMAP_HOST '[!A-Za-z0-9._-]'
check SMTP_HOST '[!A-Za-z0-9._-]'
check_port IMAP_PORT
check_port SMTP_PORT
check_secure IMAP_SECURE
check_secure SMTP_SECURE

# set_ini FILE SECTION KEY VALUE: set KEY = "VALUE" inside [SECTION], or
# at the top of FILE when SECTION is empty; every other line stays.
set_ini() {
    touch "$1"
    awk -v section="$2" -v key="$3" -v value="$4" '
        function emit() { print key " = \"" value "\""; done = 1 }
        BEGIN { inside = (section == "") }
        /^\[/ {
            if (inside && !done) emit()
            inside = ($0 == "[" section "]")
        }
        inside && $0 ~ "^" key "[ \t]*=" { if (!done) emit(); next }
        { print }
        END {
            if (!done) {
                if (!inside) print "[" section "]"
                emit()
            }
        }' "$1" > "$1.tmp"
    mv "$1.tmp" "$1"
}

mkdir -p "${PLUGINS}" "${CONFIGS}"

# Install / refresh every bundled plugin.
for p in /opt/snappymail-plugins/*; do
    [ -d "${p}" ] || continue
    name="$(basename "${p}")"
    rm -rf "${PLUGINS}/${name}"
    cp -r "${p}" "${PLUGINS}/${name}"
    echo "**** installed SnappyMail plugin: ${name}"
done

# Enable the plugin system + the transport-security plugin if the config
# does not already carry a [plugins] section.
if ! grep -q '^\[plugins\]' "${CFG}" 2>/dev/null; then
    printf '\n[plugins]\nenable = On\nenabled_list = "transport-security"\n' >> "${CFG}"
    echo "**** enabled transport-security plugin in application.ini"
fi

if [ -n "${SNAPPYMAIL_ADMIN_PASSWORD:-}" ]; then
    hash="$(printf '%s\n' "${SNAPPYMAIL_ADMIN_PASSWORD}" | htpasswd -niBC 12 admin | cut -d: -f2)"
    set_ini "${CFG}" security admin_password "${hash}"
    echo "**** SnappyMail admin password set from SNAPPYMAIL_ADMIN_PASSWORD"
fi

if [ -n "${DOMAIN:-}" ]; then
    mkdir -p "${DOMAINS}"
    DOMAIN_INI="${DOMAINS}/${DOMAIN}.ini"
    for setting in IMAP_HOST:imap_host IMAP_PORT:imap_port IMAP_SECURE:imap_secure \
                   SMTP_HOST:smtp_host SMTP_PORT:smtp_port SMTP_SECURE:smtp_secure; do
        var="${setting%%:*}"
        key="${setting#*:}"
        eval "value=\${${var}:-}"
        [ -n "${value}" ] || continue
        set_ini "${DOMAIN_INI}" "" "${key}" "${value}"
        echo "**** ${DOMAIN}: ${key} = ${value}"
    done
fi

chown -R "${UID_OWNER}" "${DATA}"
echo "**** SnappyMail plugin init done"
