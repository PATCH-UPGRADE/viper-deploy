#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Stopping Viper & Blueflow deployment. This may take a moment."
echo -e "---------------------------------------------------------------\n"

podman-compose -f /srv/viper/compose-aws.yml down
