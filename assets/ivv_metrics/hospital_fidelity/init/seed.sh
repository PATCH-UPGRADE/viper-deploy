#! /bin/bash

. "$(dirname "$0")/../../lib/common.sh"

echo -e "\n---------------------------------------------------------------"
echo "Seeding Blueflow"
echo -e "---------------------------------------------------------------\n"

mkdir -p "${ASSETS_DIR}/blueflow-init"
cp "${ASSETS_DIR}/seed-blueflow.sh" "${ASSETS_DIR}/blueflow-init/seed-blueflow.sh"
cp "${ASSETS_DIR}/blueflow_sample_assets.json" "${ASSETS_DIR}/blueflow-init/blueflow_sample_assets.json"
compose exec -T blueflow bash /blueflow-init/seed-blueflow.sh
# Blueflow's create_assets is not currently idempotent
compose exec -T blueflow /app/.venv/bin/python project/manage.py create_assets --filepath /blueflow-init/blueflow_sample_assets.json 2>/dev/null || true
