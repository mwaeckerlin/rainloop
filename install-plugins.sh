#!/bin/sh
# Sync the bundled SnappyMail plugin(s) into the data volume and enable
# them in application.ini. Idempotent — safe to run on every start.
#
# SNAPPYMAIL_DATA  data dir (default /app/data), where SnappyMail keeps
#                  _data_/_default_/{plugins,configs}
# SM_DATA_UID      uid that owns the data (default 100, the snappymail
#                  runtime user)
set -eu

DATA="${SNAPPYMAIL_DATA:-/app/data}"
UID_OWNER="${SM_DATA_UID:-100}"
DEFAULT="${DATA}/_data_/_default_"
PLUGINS="${DEFAULT}/plugins"
CONFIGS="${DEFAULT}/configs"
CFG="${CONFIGS}/application.ini"

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

chown -R "${UID_OWNER}" "${DATA}"
echo "**** SnappyMail plugin init done"
