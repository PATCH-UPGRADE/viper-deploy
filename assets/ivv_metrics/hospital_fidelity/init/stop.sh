#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Stopping Viper & Blueflow deployment. This may take a moment."
echo -e "---------------------------------------------------------------\n"

podman-compose -f /srv/viper-deploy/assets/compose-aws.yml down
