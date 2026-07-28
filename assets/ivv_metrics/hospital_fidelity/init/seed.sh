echo -e "\n---------------------------------------------------------------"
echo "Seeding Blueflow"
echo -e "---------------------------------------------------------------\n"

cp /srv/viper/seed-blueflow.sh /srv/viper/blueflow-init/seed-blueflow.sh
cp /srv/viper/blueflow_sample_assets.json /srv/viper/blueflow-init/blueflow_sample_assets.json
podman-compose -f /srv/viper/compose-aws.yml exec blueflow bash /blueflow-init/seed-blueflow.sh
# Blueflow's create_assets is not currently idempotent
podman-compose -f /srv/viper/compose-aws.yml exec -T blueflow /app/.venv/bin/python project/manage.py create_assets --filepath /blueflow-init/blueflow_sample_assets.json 2>/dev/null || true
