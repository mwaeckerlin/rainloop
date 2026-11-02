#!/usr/bin/env bash
# Documentation contract: the README must describe the admin login the
# way SnappyMail performs it.
#
# SnappyMail generates the admin password on the first call of the admin
# panel, writes it to `_data_/_default_/admin_password.txt` in the data
# volume and stores its hash in application.ini
# (app/libraries/RainLoop/ActionsAdmin.php: twelve characters from
# random_bytes(16) whenever security.admin_password is empty). There is
# no fixed default: an operator who reads one in the README cannot log
# in at all, and a README that names a literal password teaches him to
# leave it standing.
#
# Usage: tests/docs-contract.sh

set -uo pipefail

cd "$(dirname "$0")/.."

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

echo "==> Documentation contract: the admin login as SnappyMail sets it"

# A literal password in the list that names the admin user. The
# password of the contacts database is a different list and stays.
_admin_password_in() {
    awk '
        /^- *User: *`admin`/ { seen = NR }
        seen && NR > seen && NR <= seen + 2 && /^- *Password:/ { print NR ": " $0 }
    ' "$1"
}

# The negative case first: the text the README carried until 2026-11-01
# is kept as a fixture, and the check has to find the password in it. A
# check that finds nothing anywhere would pass over every README.
if [[ -n "$(_admin_password_in tests/fixtures/readme-with-admin-password.md)" ]]; then
    _pass "finds_a_literal_admin_password"
else
    _fail "finds_a_literal_admin_password" \
        "the check does not even find the password in its own fixture"
fi

ADMIN_PAIR="$(_admin_password_in README.md)"
if [[ -n "${ADMIN_PAIR}" ]]; then
    _fail "no_literal_admin_password" \
        "the README names a fixed admin password (${ADMIN_PAIR}); SnappyMail generates one"
else
    _pass "no_literal_admin_password"
fi

if grep -q 'admin_password.txt' README.md; then
    _pass "names_the_password_file"
else
    _fail "names_the_password_file" \
        "the README does not say where the generated password is written"
fi

if grep -q 'SNAPPYMAIL_ADMIN_PASSWORD' README.md; then
    _pass "names_the_own_password"
else
    _fail "names_the_own_password" \
        "the README does not say how to set a password of your own"
fi

echo ""
echo "==> Documentation contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed checks: ${FAILED_NAMES[*]}"
    exit 1
fi
