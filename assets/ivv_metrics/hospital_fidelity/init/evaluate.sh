#!/usr/bin/env bash

set -euo pipefail

VIPER_URL="${VIPER_URL:-http://localhost:3000}"
VIPER_API_KEY_FILE="${VIPER_API_KEY_FILE:-/srv/viper/VIPER_API_KEY}"
BLUEFLOW_ASSETS_FILE="${BLUEFLOW_ASSETS_FILE:-/srv/viper/blueflow_sample_assets.json}"

if [[ ! -r "${VIPER_API_KEY_FILE}" ]]; then
  echo "ERROR: Viper API key file is not readable: ${VIPER_API_KEY_FILE}" >&2
  exit 1
fi

if [[ ! -r "${BLUEFLOW_ASSETS_FILE}" ]]; then
  echo "ERROR: Blueflow asset file is not readable: ${BLUEFLOW_ASSETS_FILE}" >&2
  exit 1
fi

VIPER_API_KEY=$(<"${VIPER_API_KEY_FILE}")
BLUEFLOW_ASSET_COUNT=$(jq -er '
  if type == "array" then
    length
  else
    error("expected a JSON array")
  end
' "${BLUEFLOW_ASSETS_FILE}")

get_viper_assets_page() {
  local page="$1"
  local input

  input=$(jq -cn --argjson page "${page}" \
    '{"0":{"json":{"page":$page,"pageSize":100}}}')

  curl --silent --show-error --fail-with-body --get \
    "${VIPER_URL}/api/trpc/assets.getMany" \
    -H "Authorization: Bearer ${VIPER_API_KEY}" \
    --data-urlencode "batch=1" \
    --data-urlencode "input=${input}"
}

VIPER_RESPONSE=$(get_viper_assets_page 1)

VIPER_ASSET_COUNT=$(jq -er '
  .[0].result.data.json.totalCount
  | if type == "number" then . else error("missing numeric totalCount") end
' <<<"${VIPER_RESPONSE}")

VIPER_TOTAL_PAGES=$(jq -er '
  .[0].result.data.json.totalPages
  | if type == "number" then . else error("missing numeric totalPages") end
' <<<"${VIPER_RESPONSE}")

VIPER_MACS=$(jq -r '
  .[0].result.data.json.items[]
  | .macAddress // empty
  | ascii_downcase
  | gsub("[^0-9a-f]"; "")
  | select(length > 0)
' <<<"${VIPER_RESPONSE}")

for ((page = 2; page <= VIPER_TOTAL_PAGES; page++)); do
  VIPER_RESPONSE=$(get_viper_assets_page "${page}")
  PAGE_MACS=$(jq -r '
    .[0].result.data.json.items[]
    | .macAddress // empty
    | ascii_downcase
    | gsub("[^0-9a-f]"; "")
    | select(length > 0)
  ' <<<"${VIPER_RESPONSE}")

  if [[ -n "${PAGE_MACS}" ]]; then
    VIPER_MACS+=$'\n'"${PAGE_MACS}"
  fi
done

MATCHED_BLUEFLOW_ASSET_COUNT=$(jq -er --arg viper_macs "${VIPER_MACS}" '
  (
    $viper_macs
    | split("\n")
    | map(select(length > 0))
    | reduce .[] as $mac ({}; .[$mac] = true)
  ) as $viper_mac_set
  | [
      .[]
      | (
          .fields.mac_address // ""
          | ascii_downcase
          | gsub("[^0-9a-f]"; "")
        ) as $mac
      | select($mac != "" and $viper_mac_set[$mac] == true)
    ]
  | length
' "${BLUEFLOW_ASSETS_FILE}")

if (( BLUEFLOW_ASSET_COUNT == 0 )); then
  PERCENTAGE="0.00"
  PASSED="false"
else
  PERCENTAGE=$(awk -v matched="${MATCHED_BLUEFLOW_ASSET_COUNT}" \
    -v blueflow="${BLUEFLOW_ASSET_COUNT}" \
    'BEGIN { printf "%.2f", (matched / blueflow) * 100 }')

  PASSED=$(awk -v matched="${MATCHED_BLUEFLOW_ASSET_COUNT}" \
    -v blueflow="${BLUEFLOW_ASSET_COUNT}" \
    'BEGIN { print ((matched / blueflow) * 100 > 65) ? "true" : "false" }')
fi

echo "-------------------------------------------------------------"
echo "Blueflow assets seeded: ${BLUEFLOW_ASSET_COUNT}"
echo "Total Viper assets: ${VIPER_ASSET_COUNT}"
echo "Blueflow assets found in Viper by MAC address: ${MATCHED_BLUEFLOW_ASSET_COUNT}"
echo "Blueflow assets represented in Viper: ${PERCENTAGE}%"
echo "Pass (>65%): ${PASSED}"
echo "-------------------------------------------------------------"
