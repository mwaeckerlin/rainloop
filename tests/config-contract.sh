#!/usr/bin/env bash
# Config contract of the version line 2: the PHP image inherits the
# hardening of mwaeckerlin/php-fpm.
#
#   - session upload progress is off and locked in the pool, the mitigation
#     named with the leaked details of CVE-2026-109618 and CVE-2026-109619
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
echo "        PHP in the image: $(docker run --rm --pull=never "${IMAGE}" -v 2>&1 | head -n 1)"

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

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
