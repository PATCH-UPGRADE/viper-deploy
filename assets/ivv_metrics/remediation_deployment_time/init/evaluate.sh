#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "$0")/../../lib/common.sh"

VIPER_URL="${VIPER_URL:-http://localhost:3000}"
INNGEST_URL="${INNGEST_URL:-http://localhost:8288}"
RDT_VULNERABILITY_ID_FILE="${RDT_VULNERABILITY_ID_FILE:-${ASSETS_DIR}/RDT_VULNERABILITY_ID}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-5}"

if [[ ! -r "${VIPER_API_KEY_FILE}" ]]; then
  echo "ERROR: Viper API key file is not readable: ${VIPER_API_KEY_FILE} — run 'just create-viper-api-key' first" >&2
  exit 1
fi

if [[ ! -r "${RDT_VULNERABILITY_ID_FILE}" ]]; then
  echo "ERROR: vulnerability id file is not readable: ${RDT_VULNERABILITY_ID_FILE} — run 'just seed' first" >&2
  exit 1
fi

VIPER_API_KEY=$(<"${VIPER_API_KEY_FILE}")
VULNERABILITY_ID=$(<"${RDT_VULNERABILITY_ID_FILE}")

SUBMITTED_AT=$(date +%s)

CREATE_RESPONSE=$(curl --silent --show-error --fail-with-body \
  -X POST "${VIPER_URL}/api/v1/remediations" \
  -H "Authorization: Bearer ${VIPER_API_KEY}" \
  -H "Content-Type: application/json" \
  --data-raw "$(jq -cn --arg vulnId "${VULNERABILITY_ID}" '{
    vulnerabilityId: $vulnId,
    description: "RDT metric: firmware update for the Infuse Station IQ",
    narrative: "Synthetic remediation submitted by the remediation_deployment_time IV&V metric.",
    artifacts: [{
      name: "RDT metric placeholder artifact",
      artifactType: "Documentation",
      downloadUrl: "https://example.com/rdt-metric-notes.pdf"
    }]
  }')") || { echo "ERROR: remediation POST failed: ${CREATE_RESPONSE}" >&2; exit 1; }

REMEDIATION_ID=$(jq -er '.remediation.id' <<<"${CREATE_RESPONSE}")
echo "Submitted remediation ${REMEDIATION_ID}"

# A 200 from the POST does not prove the job was enqueued (the API swallows
# dispatch failures) — finding the event on the Inngest API is the proof.
EVENT_ID=""
RUN_ID=""
for _ in $(seq 1 12); do
  EVENT_ID=$(curl --silent --fail "${INNGEST_URL}/v1/events?name=remediation/analysis.requested" \
    | jq -r --arg rid "${REMEDIATION_ID}" \
      '[.data[] | select(.data.remediationId == $rid)][0].id // empty' || true)
  if [[ -n "${EVENT_ID}" ]]; then
    RUN_ID=$(curl --silent --fail "${INNGEST_URL}/v1/events/${EVENT_ID}/runs" \
      | jq -r '.data[0].run_id // empty' || true)
    [[ -n "${RUN_ID}" ]] && break
  fi
  sleep 5
done

if [[ -z "${EVENT_ID}" ]]; then
  echo "ERROR: no remediation/analysis.requested event for ${REMEDIATION_ID} after 60s — the dispatch was dropped or Inngest is unreachable at ${INNGEST_URL}" >&2
  exit 1
fi

if [[ -z "${RUN_ID}" ]]; then
  echo "ERROR: event ${EVENT_ID} exists but no run started for it after 60s — is the Viper app registered with Inngest?" >&2
  exit 1
fi

echo "Analysis run ${RUN_ID}; polling until it terminates (timeout ${TIMEOUT_SECONDS}s)..."

# Poll on ended_at, not status: the event-runs listing reports "Completed" from
# the moment the run starts, while ended_at stays null until it really finishes.
RUN_JSON=""
DEADLINE=$(( $(date +%s) + TIMEOUT_SECONDS ))
while (( $(date +%s) < DEADLINE )); do
  RUN_JSON=$(curl --silent --fail "${INNGEST_URL}/v1/runs/${RUN_ID}" | jq -c '.data // empty' || true)
  if [[ -n "${RUN_JSON}" ]] && [[ "$(jq -r '.ended_at // "null"' <<<"${RUN_JSON}")" != "null" ]]; then
    break
  fi
  sleep "${POLL_SECONDS}"
done

if [[ -z "${RUN_JSON}" ]] || [[ "$(jq -r '.ended_at // "null"' <<<"${RUN_JSON}")" == "null" ]]; then
  echo "ERROR: run ${RUN_ID} had not finished after ${TIMEOUT_SECONDS}s — giving up." >&2
  exit 1
fi

STATUS=$(jq -r '.status' <<<"${RUN_JSON}")

if [[ "${STATUS}" != "Completed" ]]; then
  echo "ERROR: run finished as '${STATUS}': $(jq -r '.output.message // "no error message"' <<<"${RUN_JSON}")" >&2
  exit 1
fi

if jq -e '.output.skipped? // empty' <<<"${RUN_JSON}" >/dev/null; then
  echo "ERROR: analysis skipped ($(jq -r '.output.skipped' <<<"${RUN_JSON}")) — fixture preconditions broke; re-run 'just seed'" >&2
  exit 1
fi

COMPLETED_AT=$(date +%s)
RUN_SECONDS=$(jq -r '
  def epoch: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
  (.ended_at | epoch) - (.run_started_at | epoch)
' <<<"${RUN_JSON}")

echo "-------------------------------------------------------------"
echo "Remediation submitted:          ${REMEDIATION_ID}"
echo "Notification created:           $(jq -r '.output.notificationId' <<<"${RUN_JSON}")"
echo "Inngest run status:             ${STATUS}"
echo "Inngest run duration (seconds): ${RUN_SECONDS}"
echo "Submit-to-complete wall clock:  $(( COMPLETED_AT - SUBMITTED_AT )) seconds"
echo "-------------------------------------------------------------"
