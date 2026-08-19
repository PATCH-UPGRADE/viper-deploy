#!/usr/bin/env bash
set -euo pipefail

# Seed the WHS lab from the models file that lives in the repo.
#   1. import  : POST /api/v1/models/import   (multipart file=@<repo file>)
#   2. deploy  : POST /api/v1/deploy          (async; 409 = work already in flight)
#   3. wait    : GET  /api/v1/deployment-status until the deployment finishes
#
# We reference the repo file — we do NOT copy it.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_FILE="${MODELS_FILE:-${SCRIPT_DIR}/../whs-models.yaml}"
URL="${URL:-http://localhost:8080}"
BUDGET_SECONDS="${BUDGET_SECONDS:-900}"   # total wall-clock budget (deploy can take minutes)
POLL_SECONDS="${POLL_SECONDS:-5}"         # pause between status polls
REQ_TIMEOUT="${REQ_TIMEOUT:-15}"          # per-request socket timeout (never unbounded)
PYTHON="${PYTHON:-python3}"

if [[ ! -r "$MODELS_FILE" ]]; then
  echo "ERROR: models file not readable: $MODELS_FILE" >&2
  exit 1
fi

echo "Seed WHS lab"
echo "  models file: $MODELS_FILE"
echo "  api:         $URL"
echo "  budget:      ${BUDGET_SECONDS}s  (poll ${POLL_SECONDS}s, req ${REQ_TIMEOUT}s)"
echo

# 1. Import ----------------------------------------------------------------
# Import loads the models into the store and (background) regenerates the
# layout. This is NOT the deploy — that is step 2. curl --fail-with-body
# turns any 4xx/5xx into a non-zero exit so set -e aborts the recipe.
echo "[1/3] POST /api/v1/models/import"
IMPORT_OUT="$(curl --silent --show-error --fail-with-body \
  --connect-timeout 10 --max-time 60 \
  -X POST "${URL}/api/v1/models/import" -F "file=@${MODELS_FILE}")"
echo "      ${IMPORT_OUT}"

# 2. Start the deploy + 3. Wait for it to finish ----------------------------
# The import's layout regeneration holds the server's deployment_lock, so a
# POST /deploy issued in that window returns 409 "deployment running". That is
# not a failure — it is "something is already in the deploy path". So:
#   - keep POST /deploy until the server accepts one (200) or the budget runs;
#   - then poll /deployment-status; every probe is time-bounded, and a
#     timeout / 4xx-5xx / null just means "not finished yet", so we keep
#     waiting; stop on the first running==false (a completed result);
#   - fail if the budget is spent or the finished result has failures/orphans.
echo "[2/3] POST /api/v1/deploy (retrying across 409 while the lock is held)"
echo "[3/3] Waiting for the deployment to finish"
"$PYTHON" - "${URL}" "${BUDGET_SECONDS}" "${POLL_SECONDS}" "${REQ_TIMEOUT}" <<'PY'
import json, sys, time, urllib.request, urllib.error

url, budget_s, poll_s, req_timeout = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
deadline = time.monotonic() + budget_s

def post_deploy():
    req = urllib.request.Request(url + "/api/v1/deploy", data=b"", method="POST")
    try:
        with urllib.request.urlopen(req, timeout=req_timeout) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        return e.code, body

def get_status():
    try:
        with urllib.request.urlopen(url + "/api/v1/deployment-status", timeout=req_timeout) as r:
            raw = r.read().decode("utf-8", "replace")
        return json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError:
        return None
    except Exception:
        return None

# 2. Start the deploy (tolerate 409 while the lock is held by the import).
completed = None
while True:
    if completed is not None:
        break
    code, body = post_deploy()
    if 200 <= code < 300:
        print(f"      deploy started (HTTP {code})")
        break
    if code == 409:
        # Lock held (import regeneration / an in-flight deploy). If that
        # work has already finished, there is a completed result to report
        # and no point starting a second deployment.
        st = get_status()
        if st is not None and st.get("running") is False:
            completed = st
            continue
    else:
        sys.stderr.write(f"ERROR: POST /deploy -> HTTP {code}: {body}\n")
        sys.exit(1)
    if time.monotonic() >= deadline:
        sys.stderr.write("ERROR: could not start deploy within budget (lock never freed)\n")
        sys.exit(1)
    time.sleep(poll_s)

# 3. Wait for the deployment to finish (first running==false = completed).
while completed is None:
    status = get_status()
    if status is not None and status.get("running") is False:
        completed = status
        break
    if time.monotonic() >= deadline:
        sys.stderr.write(f"ERROR: deploy did not finish within {budget_s}s\n")
        sys.exit(1)
    time.sleep(poll_s)
status = completed

ok = not status.get("failures") and not status.get("dependency_failures") and not status.get("orphans")
print("      deployment result:")
for k in ("running", "successes", "failures", "dependency_failures", "ignored", "orphans"):
    print(f"        {k:<18}{status.get(k)}")
if not ok:
    sys.stderr.write("ERROR: deployment finished but reported failures/orphans — see above\n")
    sys.exit(1)
print("      seed complete")
PY
