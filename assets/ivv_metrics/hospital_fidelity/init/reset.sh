#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Resetting Viper & Blueflow deployment. This may take a moment."
echo "All Viper & Blueflow data will be cleared."
echo -e "---------------------------------------------------------------\n"

podman-compose -f /srv/viper/compose-aws.yml down --volumes
podman-compose -f /srv/viper/compose-aws.yml --env-file /srv/viper/.env up -d

