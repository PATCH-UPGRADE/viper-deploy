#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "$0")/../../lib/common.sh"

STATE_FILE="${TARGET_HOSPITAL_STATE_FILE:-${ASSETS_DIR}/TARGET_HOSPITAL_ASSET_COUNT}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo -e "\n---------------------------------------------------------------"
echo "Scaling the target hospital environment (adding 1300 assets)"
echo -e "---------------------------------------------------------------\n"

if [[ ! -f "${STATE_FILE}" ]]; then
  echo "ERROR: environment not seeded yet — run 'just seed' first." >&2
  exit 1
fi

CURRENT=$(<"${STATE_FILE}")
if (( CURRENT >= 1500 )); then
  echo "ERROR: environment already scaled (${CURRENT} assets per ${STATE_FILE})." >&2
  echo "Run 'just reset' to clear ALL Viper data and start over." >&2
  exit 1
fi

bash "${SCRIPT_DIR}/create-assets.sh" 201 1300

echo 1500 > "${STATE_FILE}"
echo "Scaled to 1500 assets."
