# Hospital Fidelity Metric

## Metric: 65% of devices in a hospital CMMS (Blueflow) are represented in the Viper VMP.

### Navigate to the justfile
- cd /srv/viper/hospital_fidelity

### Testing commands:

#### just start
- Start the Viper & Blueflow deployment

#### just stop
- Stop the Viper & Blueflow deployment. This does not clear data.

#### just reset
- Reset the environment and clear all data in order to re-run tests

#### just seed
- Seed sample assets into Blueflow CMMS

#### just integrate
- Integrate with the Blueflow CMMS

