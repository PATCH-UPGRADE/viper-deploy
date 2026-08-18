#! /bin/bash

. "$(dirname "$0")/../../lib/common.sh"

echo -e "\n---------------------------------------------------------------"
echo "Stopping Viper & Blueflow deployment. This may take a moment."
echo -e "---------------------------------------------------------------\n"

compose down
