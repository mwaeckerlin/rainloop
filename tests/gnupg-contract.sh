#!/usr/bin/env bash
# gnupg contract: php-fpm of the image loads the php-gnupg module.
#
# Usage: tests/gnupg-contract.sh IMAGE

set -uo pipefail

IMAGE="${1:?usage: tests/gnupg-contract.sh IMAGE}"

echo "==> gnupg contract: ${IMAGE}"
modules=$(docker run --rm --pull=never --entrypoint /usr/sbin/php-fpm "${IMAGE}" -m 2>&1)
if grep -qx gnupg <<< "${modules}"; then
    echo "  PASS  gnupg_loaded"
else
    echo "  FAIL  gnupg_loaded: $(echo ${modules})"
    exit 1
fi
