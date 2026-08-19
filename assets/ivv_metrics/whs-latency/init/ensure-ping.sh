#!/usr/bin/env bash
set -euo pipefail

# Ensure the 'whs' container has iputils-ping installed (idempotent).
# Debian/trixie image does not ship ping. Safe to re-run.
NAME="${WHS_NAME:-whs}"

if ! podman container exists "$NAME" 2>/dev/null; then
  echo "ERROR: container '$NAME' does not exist (run 'just start' first)" >&2
  exit 1
fi

if podman exec "$NAME" sh -c 'command -v ping' >/dev/null 2>&1; then
  echo "ping: already installed in '$NAME'"
  exit 0
fi

echo "ping: installing iputils-ping into '$NAME' (debian) ..."
# Noninteractive, quiet. Keep errors on stderr; suppress the noisy apt stdout.
DEBIAN_FRONTEND=noninteractive podman exec "$NAME" sh -c \
  'apt-get update -qq >/dev/null 2>&1 || apt-get update >/dev/null 2>&1; \
   DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -qq iputils-ping >/dev/null 2>&1' || true

if podman exec "$NAME" sh -c 'command -v ping' >/dev/null 2>&1; then
  echo "ping: installed in '$NAME'"
else
  echo "ERROR: ping still not available in '$NAME' after install" >&2
  exit 1
fi
