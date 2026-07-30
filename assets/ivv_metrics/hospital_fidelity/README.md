# Hospital Fidelity Metric

## Metric: 65% of devices in a hospital CMMS (Blueflow) are represented in the Viper VMP

*Note that `just create-viper-api-key` creates an API key used by other commands that will expire after 24 hours by design. Re-run this command to create a new key.*

### Navigate to the justfile
- cd /srv/viper/hospital_fidelity

### Testing commands:

#### Create an API key, run the evaluation, seeding, & integration, followed by another evaluation (following commands in sequence)
- just test

#### Create Viper API key
- just crete-viper-api-key

#### Seed sample assets into Blueflow CMMS
- just seed

#### Check number of assets in Viper prior to integrating with Blueflow
- just evaluate

#### Integrate with the Blueflow CMMS.
*This has an intentional non-scientific `sleep` to allow the initial sync to complete on slower EC2 instances*
- just integrate

#### Check number of assets in Viper after integrating with Blueflow
- just evaluate

### Other commands

#### Start the Viper & Blueflow deployment
- just start

#### Stop the Viper & Blueflow deployment -- this does not clear data
- just stop

#### Reset the environment and clear all data in order to re-run tests
- just reset