#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Starting Viper & Blueflow deployment. This may take a moment."
echo -e "---------------------------------------------------------------\n"

podman-compose -f /srv/viper/compose-aws.yml --env-file /srv/viper/.env up -d
