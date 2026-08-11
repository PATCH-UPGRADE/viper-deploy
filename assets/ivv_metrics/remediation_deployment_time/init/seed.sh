#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Seeding the remediation deployment time fixture"
echo -e "---------------------------------------------------------------\n"

SEED_OUTPUT=$(podman-compose -f /srv/viper-deploy/assets/compose-aws.yml exec -T viper npx tsx scripts/seed-remediation-metric.ts)
echo "${SEED_OUTPUT}"

VULNERABILITY_ID=$(echo "${SEED_OUTPUT}" | grep '^VULNERABILITY_ID=' | cut -d= -f2-)

if [ -z "${VULNERABILITY_ID}" ]; then
  echo "ERROR: seed script did not print VULNERABILITY_ID=..." >&2
  exit 1
fi

echo ${VULNERABILITY_ID} > /srv/viper-deploy/assets/RDT_VULNERABILITY_ID
