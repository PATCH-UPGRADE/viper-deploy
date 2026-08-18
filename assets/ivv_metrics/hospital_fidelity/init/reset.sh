#! /bin/bash

. "$(dirname "$0")/../../lib/common.sh"

echo -e "\n---------------------------------------------------------------"
echo "Resetting Viper & Blueflow deployment. This may take a moment."
echo "All Viper & Blueflow data will be cleared."
echo -e "---------------------------------------------------------------\n"

compose down
# Avoid removing Caddy's volumes
container volume rm viper_pgdata viper_blueflow-pgdata viper_blueflow-redis-data viper_viper-stamps
compose up -d

