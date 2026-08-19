# Remediation Deployment Time / Decision Generation Metric

## Metric: time for Viper's remediation analysis to complete after a TA4 remediation is submitted

* The time it takes for VIPER to generate decision support resources for a TA4 remediation (decision generation)
* The time it takes to make a remediation available for operators to deploy (remediation deployment time)

Submits one remediation to `POST /api/v1/remediations` and reports how long the
`analyze-remediation` Inngest job took to terminate. 
The duration comes from Inngest's own run record (`ended_at − run_started_at`),
not from a client-side stopwatch.

*The reported number varies run to run — the job makes three LLM calls.
This metric reports duration only; it deliberately asserts
nothing about the analysis content.*

*This metric requires a working `ANTHROPIC_API_KEY` in the Viper container —
without one the job fails after ~5 minutes of retries instead of producing a
number.

### Navigate to the justfile
- cd /srv/viper-deploy/assets/ivv_metrics/remediation_deployment_time

### Testing commands:

#### Create an API key, seed the fixture, then submit and measure (following commands in sequence)
- just test

#### Create Viper API key
- just create-viper-api-key

#### Seed the metric fixture
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

### Requirements

- `jq`, `curl`, `just` (all preinstalled on the deployed box)
- expect `just evaluate` to take roughly 2–6 minutes end to end
