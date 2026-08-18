#! /bin/bash

. "$(dirname "$0")/../../lib/common.sh"

VIPER_API_KEY=$(compose exec -T viper npm run db:create-test-api-key --silent 2>/dev/null | grep '^API_KEY=' | cut -d= -f2-)
echo $VIPER_API_KEY > "${VIPER_API_KEY_FILE}"
