# Remediation Deployment Time Metric

## Metric: time for Viper's remediation analysis to complete after a TA4 remediation is submitted

Submits one remediation to `POST /api/v1/remediations` and reports how long the
`analyze-remediation` Inngest job took to terminate — meaning the VEX, triage,
and mitigation agents have all run. The duration comes from Inngest's own run
record (`ended_at − run_started_at`), not from a client-side stopwatch.

*Note that `just create-viper-api-key` creates an API key used by other commands
that will expire after 24 hours by design. Re-run this command to create a new key.*

*The reported number varies run to run — the job makes three LLM calls (two with
extended thinking), and a single mitigation step has been observed near 95
seconds on its own. This metric reports duration only; it deliberately asserts
nothing about the analysis content.*

*This metric requires a working `ANTHROPIC_API_KEY` in the Viper container —
without one the job fails after ~5 minutes of retries instead of producing a
number. `compose-aws.yml` ships a placeholder and reads the real key from the
shell environment: `export ANTHROPIC_API_KEY=sk-ant-...` before `just start`.
Never commit a real key to this repo.*

### Navigate to the justfile
- cd /srv/viper/ivv_metrics/remediation_deployment_time

### Testing commands:

#### Create an API key, seed the fixture, then submit and measure (following commands in sequence)
- just test

#### Create Viper API key
- just create-viper-api-key

#### Seed the metric fixture
*A synthetic vulnerability (CVE-2099-0371) plus three infusion-pump assets. Safe
to re-run — each run deletes and recreates the fixture, so a previous
measurement's analysis results can never leak into the next one.*
- just seed

#### Submit one remediation and print the analysis duration
- just evaluate

### Other commands

#### Start the Viper & Blueflow deployment
- just start

#### Stop the Viper & Blueflow deployment -- this does not clear data
- just stop

#### Reset the environment and clear all data in order to re-run tests
- just reset

### Example output (real run, local dev stack)

```
Submitted remediation cmsjh4az00007h6tgfjl7rbtq
Analysis run 01KZF30BJ7E2HXXHRJY4ZNHRHX; polling until it terminates (timeout 900s)...
-------------------------------------------------------------
Remediation submitted:          cmsjh4az00007h6tgfjl7rbtq
Notification created:           cmsjh4bdh000ch6tgwxy9nfgi
Inngest run status:             Completed
Inngest run duration (seconds): 131
Submit-to-complete wall clock:  132 seconds
-------------------------------------------------------------
```

The script exits non-zero, with the reason, if the remediation never produced an
Inngest event, if the run failed, or if the analysis no-opped because the
fixture was missing its vulnerability.

### Running locally (developer machine)

To run against a local Viper checkout instead of the deployed stack, generate
the two input files in the checkout, then point `evaluate.sh` at them. Every URL
and path is overridable:

```

    cd ~/path/to/viper
    npx tsx scripts/seed-remediation-metric.ts | grep '^VULNERABILITY_ID=' | cut -d= -f2- > /tmp/RDT_VULNERABILITY_ID
    npm run db:create-test-api-key --silent | grep '^API_KEY=' | cut -d= -f2- > /tmp/VIPER_API_KEY

    cd -
    VIPER_URL=http://localhost:3000 \
    INNGEST_URL=http://localhost:8288 \
    VIPER_API_KEY_FILE=/tmp/VIPER_API_KEY \
    RDT_VULNERABILITY_ID_FILE=/tmp/RDT_VULNERABILITY_ID \
    bash init/evaluate.sh

```

The checkout needs postgres running, migrations applied, a real
`ANTHROPIC_API_KEY` in `.env`, and both `npm run dev` and `npm run inngest:dev`
up. Override `TIMEOUT_SECONDS` (default 900) and `POLL_SECONDS` (default 5) to
change how long the script waits.

### Requirements

- `jq`, `curl`, `just` (all preinstalled on the deployed box)
- expect `just evaluate` to take roughly 2–6 minutes end to end
