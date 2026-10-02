#!/usr/bin/env bash
# Build contract: release-signature verification must be ENFORCED in
# BOTH images (php-fpm backend AND nginx static-file proxy — the nginx
# tree carries all JavaScript the browser executes).
#
#   - key: the pinned file must hold a real, importable OpenPGP public
#     key, never the shipped placeholder. A silent downgrade back to the
#     placeholder disables verification for every future build.
#   - verify: a production build (no SKIP_GPG_VERIFY) must actually run
#     the signature check and report it, for both images.
#   - tamper: a build whose pinned key is NOT the release signer must
#     fail — this is the property the whole mechanism exists for.
#   - accept: the escape hatch SKIP_GPG_VERIFY=1 must still build —
#     that is the documented path for test harnesses.
#
# Usage: tests/build-verification.sh

set -uo pipefail

cd "$(dirname "$0")/.."

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

echo "==> Build verification: the pinned key must be real and enforced"

# ---------------------------------------------------------------- key
if grep -q '^Placeholder ' snappymail-signing-key.asc; then
    _fail "key_is_real" "snappymail-signing-key.asc is still the placeholder"
elif gpg --show-keys snappymail-signing-key.asc >/dev/null 2>&1; then
    _pass "key_is_real"
else
    _fail "key_is_real" "gpg cannot read a public key from the pinned file"
fi

# ------------------------------------------------------------- verify
# A production build must SAY it verified; a build that silently skips
# the check would otherwise pass unnoticed.
_verify_build() {
    local name="$1" dockerfile="$2" target="$3"
    local out
    if out=$(docker build -f "${dockerfile}" --target "${target}" . 2>&1); then
        if [[ "${out}" == *"signature verified"* || "${out}" == *"Good signature"* ]]; then
            _pass "verify_${name}"
        else
            _fail "verify_${name}" "build succeeded without reporting a signature check"
        fi
    else
        _fail "verify_${name}" "production build failed: ${out}"
    fi
}

# ------------------------------------------------------------- tamper
# Swap in a valid but WRONG key: the download is untouched, only the
# trust anchor is foreign, so gpg must refuse the tarball.
_tamper_build() {
    local name="$1" dockerfile="$2" target="$3"
    local tmpkey out
    tmpkey=$(mktemp -d)
    # A throw-away key that never signed anything of SnappyMail.
    gpg --batch --quiet --homedir "${tmpkey}" --passphrase '' \
        --quick-generate-key "wrong-key@example.invalid" default default never \
        >/dev/null 2>&1
    gpg --batch --quiet --homedir "${tmpkey}" --armor \
        --export "wrong-key@example.invalid" > "${tmpkey}/wrong.asc" 2>/dev/null

    if [[ ! -s "${tmpkey}/wrong.asc" ]]; then
        _fail "tamper_${name}" "could not generate a throw-away key for the test"
        rm -rf "${tmpkey}"
        return
    fi

    cp snappymail-signing-key.asc "${tmpkey}/real.asc"
    cp "${tmpkey}/wrong.asc" snappymail-signing-key.asc
    out=$(docker build -f "${dockerfile}" --target "${target}" . 2>&1)
    local rc=$?
    cp "${tmpkey}/real.asc" snappymail-signing-key.asc
    rm -rf "${tmpkey}"

    if [[ ${rc} -eq 0 ]]; then
        _fail "tamper_${name}" "build succeeded against a foreign signing key"
    else
        _pass "tamper_${name}"
    fi
}

_accept_build() {
    local name="$1" dockerfile="$2" target="$3"
    local out
    if out=$(docker build -f "${dockerfile}" --target "${target}" \
                 --build-arg SKIP_GPG_VERIFY=1 . 2>&1); then
        _pass "accept_${name}_skip"
    else
        _fail "accept_${name}_skip" "escape-hatch build failed: ${out}"
    fi
}

_verify_build php_fpm Dockerfile.php-fpm php-fpm
_verify_build nginx   Dockerfile.nginx   nginx

_tamper_build php_fpm Dockerfile.php-fpm php-fpm
_tamper_build nginx   Dockerfile.nginx   nginx

_accept_build php_fpm Dockerfile.php-fpm php-fpm
_accept_build nginx   Dockerfile.nginx   nginx

echo ""
echo "==> Build verification results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed checks: ${FAILED_NAMES[*]}"
    exit 1
fi
