#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: start.sh --image IMAGE [--no-nic] [extra 'whs start' args...]" >&2
  echo "  --no-nic   do not attach the default --nic eth1 passthru" >&2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${WHS_NAME:-whs}"

IMAGE=""
NO_NIC=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || { echo "ERROR: --image requires a value" >&2; usage; exit 2; }
      IMAGE="$2"; shift 2 ;;
    --no-nic)
      NO_NIC=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$IMAGE" ]]; then
  echo "ERROR: --image is required (the justfile sets it from WHS_IMAGE)" >&2
  usage
  exit 2
fi

# 1. Ensure the container exists (create if necessary).
if podman container exists "$NAME" 2>/dev/null; then
  echo "Container '$NAME' already exists — skipping creation."
else
  ARGS=(whs start --image "$IMAGE")
  if [[ $NO_NIC -eq 0 ]]; then
    ARGS+=(--nic eth1)
  fi
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    ARGS+=("${EXTRA_ARGS[@]}")
  fi
  echo "Running: ${ARGS[*]}"
  "${ARGS[@]}"      # not exec: we still ensure ping + running state below
fi

# 2. Ensure it is actually running (start if it was left stopped).
if [[ "$(podman inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" != "true" ]]; then
  echo "Container '$NAME' is not running — starting it."
  podman start "$NAME"
fi

# 3. Ensure the container is usable for latency: ping present.
bash "${SCRIPT_DIR}/ensure-ping.sh"

echo "Container '$NAME' is up and usable (ping available)."
