echo -e "\n---------------------------------------------------------------"
echo "Seeding Blueflow"
echo -e "---------------------------------------------------------------\n"

cp /srv/viper-deploy/assets/seed-blueflow.sh /srv/viper-deploy/assets/blueflow-init/seed-blueflow.sh
cp /srv/viper-deploy/assets/blueflow_sample_assets.json /srv/viper-deploy/assets/blueflow-init/blueflow_sample_assets.json
podman-compose -f /srv/viper-deploy/assets/compose-aws.yml exec blueflow bash /blueflow-init/seed-blueflow.sh
# Blueflow's create_assets is not currently idempotent
podman-compose -f /srv/viper-deploy/assets/compose-aws.yml exec -T blueflow /app/.venv/bin/python project/manage.py create_assets --filepath /blueflow-init/blueflow_sample_assets.json 2>/dev/null || true
