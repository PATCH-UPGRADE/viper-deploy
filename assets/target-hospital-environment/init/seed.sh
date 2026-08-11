#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${TARGET_HOSPITAL_STATE_FILE:-/srv/viper-deploy/assets/TARGET_HOSPITAL_ASSET_COUNT}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo -e "\n---------------------------------------------------------------"
echo "Seeding the target hospital environment (200 assets)"
echo -e "---------------------------------------------------------------\n"

if [[ -f "${STATE_FILE}" ]]; then
  echo "ERROR: environment already seeded ($(<"${STATE_FILE}") assets per ${STATE_FILE})." >&2
  echo "Run 'just reset' to clear ALL Viper data and start over." >&2
  exit 1
fi

bash "${SCRIPT_DIR}/create-assets.sh" 1 200

echo 200 > "${STATE_FILE}"
echo "Seeded 200 assets."
