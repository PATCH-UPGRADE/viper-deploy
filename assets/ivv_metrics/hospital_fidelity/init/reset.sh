#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Resetting Viper & Blueflow deployment. This may take a moment."
echo "All Viper & Blueflow data will be cleared."
echo -e "---------------------------------------------------------------\n"

podman-compose -f /srv/viper/compose-aws.yml down
# Avoid removing Caddy's volumes
podman volume rm viper_pgdata viper_blueflow-pgdata viper_blueflow-redis-data viper_viper-stamps
podman-compose -f /srv/viper/compose-aws.yml up -d

