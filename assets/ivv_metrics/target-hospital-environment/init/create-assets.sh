#!/usr/bin/env bash

set -euo pipefail

START_INDEX="${1:?usage: create-assets.sh <start-index> <count>}"
COUNT="${2:?usage: create-assets.sh <start-index> <count>}"

VIPER_URL="${VIPER_URL:-http://localhost:3000}"
VIPER_API_KEY_FILE="${VIPER_API_KEY_FILE:-/srv/viper-deploy/assets/VIPER_API_KEY}"
SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CATALOG_FILE="${TARGET_HOSPITAL_CATALOG_FILE:-${SCRIPT_DIR}/device_catalog.json}"
BATCH_SIZE="${BATCH_SIZE:-50}"

if [[ ! -r "${VIPER_API_KEY_FILE}" ]]; then
  echo "ERROR: Viper API key file is not readable: ${VIPER_API_KEY_FILE} — run 'just create-viper-api-key' first" >&2
  exit 1
fi

VIPER_API_KEY=$(<"${VIPER_API_KEY_FILE}")
CATALOG_SIZE=$(jq -er 'length' "${CATALOG_FILE}")

build_asset() {
  local index="$1" entry="$2"
  local mac
  mac=$(printf '0a:37:%02x:%02x:%02x:%02x' \
    $(( index / 16777216 % 256 )) $(( index / 65536 % 256 )) \
    $(( index / 256 % 256 )) $(( index % 256 )))
  jq -cn --argjson i "${index}" --argjson entry "${entry}" --arg mac "${mac}" '
    {
      ip: "10.37.\($i / 250 | floor).\($i % 250 + 1)",
      upstreamApi: "https://target-hospital.example/api/assets/\($i)",
      cpe: $entry.cpe,
      role: $entry.role,
      hostname: ("th-" + ($entry.role | ascii_downcase | gsub("[^a-z0-9]+"; "-")) + "-" + ("00000\($i)" | .[-5:]) + ".hospital.local"),
      macAddress: $mac,
      serialNumber: ("TH-2026-" + ("00000\($i)" | .[-5:]))
    }'
}

post_batch() {
  local batch_file="$1"
  local body
  body=$(jq -s '{assets: .}' "${batch_file}")
  curl --silent --show-error --fail-with-body \
    -X POST "${VIPER_URL}/api/v1/assets/bulk" \
    -H "Authorization: Bearer ${VIPER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data-raw "${body}" > /dev/null
}

BATCH_FILE=$(mktemp)
trap 'rm -f "${BATCH_FILE}"' EXIT

END_INDEX=$(( START_INDEX + COUNT - 1 ))
CREATED=0
IN_BATCH=0

# The first batch of a fresh environment covers every catalog entry once, so
# all 12 device groups exist before any batch contains duplicate CPEs
# (createBulk resolves a request's CPEs concurrently; find-or-create races
# only when the group does not exist yet).
for (( i = START_INDEX; i <= END_INDEX; i++ )); do
  if (( i - START_INDEX < CATALOG_SIZE )) && (( START_INDEX == 1 )); then
    ENTRY_INDEX=$(( i - START_INDEX ))
  else
    ENTRY_INDEX=$(( RANDOM % CATALOG_SIZE ))
  fi
  ENTRY=$(jq -c ".[${ENTRY_INDEX}]" "${CATALOG_FILE}")
  build_asset "${i}" "${ENTRY}" >> "${BATCH_FILE}"
  IN_BATCH=$(( IN_BATCH + 1 ))

  FLUSH=0
  (( IN_BATCH >= BATCH_SIZE )) && FLUSH=1
  (( i == END_INDEX )) && FLUSH=1
  (( START_INDEX == 1 && i == CATALOG_SIZE )) && FLUSH=1

  if (( FLUSH )); then
    post_batch "${BATCH_FILE}"
    CREATED=$(( CREATED + IN_BATCH ))
    echo "Created ${CREATED}/${COUNT} assets..."
    : > "${BATCH_FILE}"
    IN_BATCH=0
  fi
done
