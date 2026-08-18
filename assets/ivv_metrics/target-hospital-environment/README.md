# Target Hospital Environment

## A 1,500-asset hospital fleet seeded directly into Viper

Populates the deployed Viper instance with assets sampled from a small catalog
of medical-device types (`device_catalog.json` — 12 types across imaging,
infusion, monitoring, ventilation, and lab), to test scalability.

Assets are created through Viper's public bulk API (`POST /api/v1/assets/bulk`);
each catalog entry carries a versioned CPE, so the fleet spreads across 12
device groups.

*Seeded MAC addresses use the locally-administered `0a:37:…` prefix, disjoint
from `blueflow_sample_assets.json`'s. The hospital_fidelity metric counts
Blueflow assets found in Viper by MAC address — reusing Blueflow's MACs here
would make that metric pass without any integration having run.*

*`just seed` and `just scale` track what they created in
`/srv/viper-deploy/assets/TARGET_HOSPITAL_ASSET_COUNT` and refuse to double-run. To rebuild
the environment, `just reset` (clears ALL Viper data), then seed again.*

### Navigate to the justfile
- `cd /srv/viper-deploy/assets/ivv_metrics/target-hospital-environment`

### Testing commands:

#### Create an API key, seed, then scale (following commands in sequence)
- just test

#### Create Viper API key
- just create-viper-api-key

#### Seed 200 assets
- just seed

#### Add 1,300 more assets (1,500 total)
- just scale

### Other commands

#### Start the Viper & Blueflow deployment
- just start

#### Stop the Viper & Blueflow deployment -- this does not clear data
- just stop

#### Reset the environment and clear all data in order to re-run tests
- just reset

### Requirements

- `jq`, `curl`, `just` (all preinstalled on the deployed box)
- expect `just scale` to take a couple of minutes (26 sequential bulk requests)
