#!/usr/bin/env bash
set -euo pipefail

# whs start creates container and volume both named after --name (default "whs"):
#   podman run ... -v$NAME:/srv/whs --name $NAME $IMAGE
NAME="${NAME:-whs}"

echo -e "\n---------------------------------------------------------------"
echo "Destroying WHS container and volume (${NAME})"
echo -e "---------------------------------------------------------------\n"

# Stop + remove container (idempotent)
if podman container exists "${NAME}" 2>/dev/null; then
    echo "Stopping container ${NAME}..."
    podman stop "${NAME}" || true
    echo "Removing container ${NAME}..."
    podman rm "${NAME}" || true
    echo "Container removed."
else
    echo "Container ${NAME} does not exist, skipping."
fi

# Remove volume (idempotent) — must happen after the container is gone
# or the release may still be in flight
if podman volume exists "${NAME}" 2>/dev/null; then
    echo "Removing volume ${NAME}..."
    podman volume rm "${NAME}" || true
    echo "Volume removed."
else
    echo "Volume ${NAME} does not exist, skipping."
fi

echo -e "\n---------------------------------------------------------------"
echo "Destroy complete."
echo -e "---------------------------------------------------------------\n"
