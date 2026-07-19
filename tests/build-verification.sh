#!/usr/bin/env bash
# Build contract: release-signature verification must be ENFORCED in
# BOTH images (php-fpm backend AND nginx static-file proxy — the nginx
# tree carries all JavaScript the browser executes).
#
#   - reject: building either Dockerfile against the shipped
#     placeholder signing key WITHOUT the SKIP_GPG_VERIFY escape hatch
#     must fail (guard 1 fires before any download).
#   - accept: the escape hatch SKIP_GPG_VERIFY=1 must still build —
#     that is the documented path for test harnesses.
#
# The gpg verify/tamper machinery itself is covered by the mailservice
# e2e suite (tests/e2e/test_snappymail_gpg_verify.py).
#
# Usage: tests/build-verification.sh

set -uo pipefail

cd "$(dirname "$0")/.."

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

# Only meaningful against the placeholder key: with a real pinned key
# the no-SKIP build legitimately succeeds. Guard the guard.
if ! grep -q '^Placeholder ' snappymail-signing-key.asc; then
    echo "==> Real signing key pinned — placeholder reject checks not applicable."
    echo "==> Build verification results: 0 passed, 0 failed (skipped: real key)"
    exit 0
fi

_reject_build() {
    local name="$1" dockerfile="$2" target="$3"
    local out
    if out=$(docker build -f "${dockerfile}" --target "${target}" . 2>&1); then
        _fail "reject_${name}_placeholder" \
              "build succeeded although the placeholder key is active and SKIP_GPG_VERIFY is unset"
    elif [[ "${out}" == *"placeholder"* ]]; then
        _pass "reject_${name}_placeholder"
    else
        _fail "reject_${name}_placeholder" "build failed for another reason: ${out}"
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

echo "==> Build verification: placeholder key must refuse a production build"

_reject_build php_fpm Dockerfile.php-fpm php-fpm
_reject_build nginx   Dockerfile.nginx   nginx

_accept_build php_fpm Dockerfile.php-fpm php-fpm
_accept_build nginx   Dockerfile.nginx   nginx

echo ""
echo "==> Build verification results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed checks: ${FAILED_NAMES[*]}"
    exit 1
fi
