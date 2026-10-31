#!/usr/bin/env bash
# Compose contract of the version line 1.
#
#   - Published names: the shared workflow of mwaeckerlin/scratch publishes
#     every compose service that has `build` and `image`, and appends to the
#     tag the suffix of the first `branch-tags` rule that matches the branch.
#     On the branch 1 that gives exactly mwaeckerlin/rainloop:php-fpm and
#     nginx, which served the image of 2026-07-16 until this line took them
#     over, and php-fpm-1 and nginx-1, each from its own stage; and
#     `npm run deploy` pushes every one of them, or the workflow cannot join
#     its architectures.
#   - The nginx image forwards PHP to the service name of the php-fpm image.
#   - The data volume of the example lies on /app/data, the volume the image
#     declares, so configuration and accounts survive a recreate.
#   - The published port takes its host address from BIND_ADDRESS; unset or
#     empty, Docker publishes it on every address, as a bare "8080:8080" does.
#
# Usage: tests/compose-contract.sh

set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

BRANCH=1
COMPOSE=docker-compose.yml
WORKFLOW=.github/workflows/docker.yml

# renders the compose file; the empty env file keeps a .env of the repository
# out of it, and the rendered text is never printed
EMPTY_ENV=$(mktemp)
trap 'rm -f "${EMPTY_ENV}"' EXIT
_render() {
    "$@" docker compose --env-file "${EMPTY_ENV}" -f "${COMPOSE}" config --format json 2> /dev/null
}

echo "==> Compose contract: published names, PHP host, data volume, published address"

if ! RENDERED=$(_render env -u BIND_ADDRESS); then
    _fail "docker-compose_renders" "docker compose config failed on ${COMPOSE}"
    RENDERED='{"services": {}}'
else
    _pass "docker-compose_renders"
fi

# the selection and the tag rule of the job `check` of docker-image.yml in
# mwaeckerlin/scratch: `base = tag + suffix`, `latest` becomes the bare suffix
PUBLISHED=$(python3 -c '
import json, re, sys
rendered, workflow, branch, deploy = sys.argv[1:5]
services = json.loads(rendered)["services"]
quote = chr(39)
rules = json.loads(re.search(r"branch-tags:\s*" + quote + "(.*)" + quote, open(workflow).read()).group(1))
suffix = ""
for rule in rules:
    found = "branch" in rule and re.fullmatch(rule["branch"], branch)
    if found:
        suffix = found.expand(rule["suffix"])
        break
pushed = set(json.load(open(deploy))["scripts"]["deploy"].split()[3:])
for name, service in sorted(services.items()):
    if "build" not in service or not service.get("image"):
        continue
    image = service["image"]
    if ":" not in image.rsplit("/", 1)[-1]:
        image += ":latest"
    repository, tag = image.rsplit(":", 1)
    base = tag + suffix if tag != "latest" else (suffix.lstrip("-") or "latest")
    build = service["build"]
    print(repository + ":" + base, build.get("dockerfile"), build.get("target"),
          "pushed" if name in pushed else "not-pushed")
' "${RENDERED}" "${WORKFLOW}" "${BRANCH}" package.json 2>&1 | sort)
EXPECTED=$(sort <<'EOF'
mwaeckerlin/rainloop:nginx Dockerfile.nginx nginx pushed
mwaeckerlin/rainloop:nginx-1 Dockerfile.nginx nginx pushed
mwaeckerlin/rainloop:php-fpm Dockerfile.php-fpm php-fpm pushed
mwaeckerlin/rainloop:php-fpm-1 Dockerfile.php-fpm php-fpm pushed
EOF
)
if [[ "${PUBLISHED}" == "${EXPECTED}" ]]; then
    _pass "published_names_of_branch_1"
else
    _fail "published_names_of_branch_1" "the branch ${BRANCH} publishes: $(echo ${PUBLISHED})"
fi

PHP_SERVICE=$(python3 -c '
import json, sys
services = json.loads(sys.argv[1])["services"]
print(*[n for n, s in services.items() if s.get("image") == "mwaeckerlin/rainloop:php-fpm"])
' "${RENDERED}" 2>&1)
PHP_FPM_HOST=$(sed -n 's/^ENV PHP_FPM_HOST="\{0,1\}\([^" ]*\)"\{0,1\}$/\1/p' Dockerfile.nginx)
if [[ -n "${PHP_SERVICE}" && "${PHP_FPM_HOST}" == "${PHP_SERVICE}" ]]; then
    _pass "php_fpm_host_is_the_php_service"
else
    _fail "php_fpm_host_is_the_php_service" "Dockerfile.nginx sets PHP_FPM_HOST '${PHP_FPM_HOST}', the php-fpm service is '${PHP_SERVICE}'"
fi

DATA=$(python3 -c '
import json, sys
service = json.loads(sys.argv[1])["services"].get("snappymail", {})
print(*[v.get("source", "") + ":" + v["target"] for v in service.get("volumes", [])])
' "${RENDERED}" 2>&1)
if [[ "${DATA}" == "data:/app/data" ]]; then
    _pass "data_volume_on_app_data"
else
    _fail "data_volume_on_app_data" "the volumes of the service snappymail: ${DATA:-none}"
fi

# counts the published ports, their host addresses, and those on 192.0.2.10
_addresses() {
    local rendered
    rendered=$(_render "$@") || { echo "render-failed"; return; }
    echo "$(grep -o '"published"' <<< "${rendered}" | wc -l) $(grep -o '"host_ip"' <<< "${rendered}" | wc -l) $(grep -o '"host_ip": *"192\.0\.2\.10"' <<< "${rendered}" | wc -l)"
}
read -r published host_ips _ <<< "$(_addresses env -u BIND_ADDRESS)"
read -r published_empty host_ips_empty _ <<< "$(_addresses env BIND_ADDRESS=)"
read -r published_set host_ips_set matching <<< "$(_addresses env BIND_ADDRESS=192.0.2.10)"
if [[ "${published}" == render-failed || "${published_empty}" == render-failed || "${published_set}" == render-failed ]]; then
    _fail "published_address_from_bind_address" "docker compose config failed on ${COMPOSE}"
elif [[ "${published}" -gt 0 && "${host_ips}" -eq 0 && "${published_empty}" -eq "${published}" && "${host_ips_empty}" -eq 0 \
        && "${published_set}" -eq "${published}" && "${matching}" -eq "${published}" ]]; then
    _pass "published_address_from_bind_address"
else
    _fail "published_address_from_bind_address" "unset: ${published} ports, ${host_ips} host addresses; empty: ${published_empty} ports, ${host_ips_empty} host addresses; 192.0.2.10: ${matching} of ${published_set} ports"
fi

# compose warns about every variable it substitutes without a value, and a
# warning is a failure; the port form gives the inner BIND_ADDRESS a default
WARNINGS=$(env -u BIND_ADDRESS docker compose --env-file "${EMPTY_ENV}" -f "${COMPOSE}" config --format json 2>&1 > /dev/null)
if [[ -z "${WARNINGS}" ]]; then
    _pass "docker-compose_renders_without_warning"
else
    _fail "docker-compose_renders_without_warning" "${WARNINGS}"
fi

echo ""
echo "==> Compose contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
