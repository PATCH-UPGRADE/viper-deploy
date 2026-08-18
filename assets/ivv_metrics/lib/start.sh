#! /bin/bash

. "$(dirname "$0")/common.sh"

echo -e "\n---------------------------------------------------------------"
echo "Starting Viper & Blueflow deployment. This may take a moment."
echo -e "---------------------------------------------------------------\n"

compose up -d
