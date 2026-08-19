#!/usr/bin/env bash
set -euo pipefail

# Wait until the WHS devices API responds with a JSON array.
#
# A bare "HTTP 200" is NOT good enough: the container serves the SPA dev server
# on the same port, and it returns 200 + HTML for unknown paths (e.g.
# /devices, /api/devices) as soon as it is up — possibly before the backend
# is. So this wait requires a 2xx response whose body actually parses as JSON.

URL="${URL:-http://localhost:8080}"
API_PATH="${API_PATH:-/api/v1/devices}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
POLL_SECONDS="${POLL_SECONDS:-2}"

PYTHON="${PYTHON:-python3}"

"$PYTHON" - "$URL${API_PATH}" "$TIMEOUT_SECONDS" "$POLL_SECONDS" <<'PY'
import json
import sys
import time
import urllib.request
import urllib.error

url, timeout_s, poll_s = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
deadline = time.monotonic() + timeout_s

def probe():
    with urllib.request.urlopen(url, timeout=5) as resp:
        body = resp.read()
    return resp.status, body

print(f"Waiting for devices API to come online: {url} (timeout {timeout_s}s)")
while True:
    try:
        status, body = probe()
        if 200 <= status < 300:
            try:
                json.loads(body)
            except ValueError:
                pass  # 2xx but not JSON (e.g., SPA HTML fallback) — keep waiting
            else:
                print(f"online: {url} returned HTTP {status} with a JSON body")
                sys.exit(0)
        else:
            pass  # non-2xx (404/502/...) means the route isn't live yet — keep waiting
    except urllib.error.HTTPError:
        pass  # explicit 4xx/5xx during startup (backend not up) — keep waiting
    except Exception:
        pass  # connection refused / timeout — not up yet — keep waiting

    if time.monotonic() >= deadline:
        sys.stderr.write(f"ERROR: {url} did not return JSON within {timeout_s}s\n")
        sys.exit(1)
    time.sleep(poll_s)
PY
