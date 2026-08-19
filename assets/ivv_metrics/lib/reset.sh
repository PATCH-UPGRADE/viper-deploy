#! /bin/bash

. "$(dirname "$0")/common.sh"

echo -e "\n---------------------------------------------------------------"
echo "Resetting Viper & Blueflow deployment. This may take a moment."
echo "All Viper & Blueflow data will be cleared."
echo -e "---------------------------------------------------------------\n"

compose down
# Avoid removing Caddy's volumes
container volume rm viper_pgdata viper_blueflow-pgdata viper_blueflow-redis-data viper_viper-stamps
# These name rows in the database just wiped; leaving them blocks the next seed
rm -f "${VIPER_API_KEY_FILE}" "${RDT_VULNERABILITY_ID_FILE}" "${TARGET_HOSPITAL_STATE_FILE}"
echo "Cleared API key, remediation fixture id, and target hospital asset count."
compose up -d
