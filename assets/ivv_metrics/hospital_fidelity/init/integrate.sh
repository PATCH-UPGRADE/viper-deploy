#! /bin/bash

echo -e "\n---------------------------------------------------------------"
echo "Creating integration between Viper & Blueflow."
echo -e "---------------------------------------------------------------\n"

VIPER_API_KEY=$(podman-compose -f /srv/viper/compose-aws.yml exec -T viper npm run db:create-test-api-key --silent 2>/dev/null | grep '^API_KEY=' | cut -d= -f2-)
VIPER_URL="${VIPER_URL:-http://localhost:3000}"
BLUEFLOW_URL="${BLUEFLOW_URL:-http://localhost:8000}"
BLUEFLOW_INTERNAL_URL="${BLUEFLOW_INTERNAL_URL:-http://blueflow:8000}"

# ── Step A: register BlueFlow as a Viper integration ──────────────────────────
echo "==> Step A: registering BlueFlow as a Viper integration..."

STEP_A_RESPONSE=$(curl -sS -X POST "${VIPER_URL}/api/trpc/integrations.create?batch=1" \
  -H "Authorization: Bearer ${VIPER_API_KEY}" \
  -H "content-type: application/json" \
  --data-raw "{\"0\":{\"json\":{\"authType\":\"Bearer\",\"authentication\":{\"token\":\"${BLUEFLOW_API_TOKEN}\"},\"name\":\"Blueflow\",\"integrationUri\":\"${BLUEFLOW_INTERNAL_URL}/api/viper/webhook/\",\"integrationType\":\"PARTNER\",\"resourceType\":\"Asset\",\"syncEvery\":300}}}")

echo "Step A response: ${STEP_A_RESPONSE}"

# Extract integration ID from Step A response
INTEGRATION_ID=$(echo "${STEP_A_RESPONSE}" \
  | jq -r '.[0].result.data.json.id // empty' 2>/dev/null || true)

if [ -z "${INTEGRATION_ID}" ]; then
  echo "ERROR: could not extract integration ID from Step A response." >&2
  exit 1
fi

echo "==> Integration ID: ${INTEGRATION_ID}"

# ── Step B: trigger an immediate sync ─────────────────────────────────────────
# Viper owns the sync lifecycle: it generates a one-time callback token,
# calls BlueFlow's webhook with it, and BlueFlow posts assets back.
echo "==> Step B: triggering initial sync..."

curl -sS -X POST "${VIPER_URL}/api/trpc/integrations.triggerSync?batch=1" \
  -H "Authorization: Bearer ${VIPER_API_KEY}" \
  -H "Content-Type: application/json" \
  --data-raw "{\"0\":{\"json\":{\"id\":\"${INTEGRATION_ID}\"}}}"