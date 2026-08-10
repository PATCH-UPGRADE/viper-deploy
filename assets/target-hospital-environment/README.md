# Target Hospital Environment

## A representative 1,500-asset hospital fleet seeded directly into Viper

Populates the deployed Viper instance with assets sampled from a small catalog
of medical-device types (`device_catalog.json` — 12 types across imaging,
infusion, monitoring, ventilation, and lab), so IV&V metrics and demos run
against a realistically sized environment instead of an empty database.
Assets are created through Viper's public bulk API (`POST /api/v1/assets/bulk`);
each catalog entry carries a versioned CPE, so the fleet spreads across 12
device groups.

*Note that `just create-viper-api-key` creates an API key used by other commands
that will expire after 24 hours by design. Re-run this command to create a new key.*

*Seeded MAC addresses use the locally-administered `0a:37:…` prefix, disjoint
from `blueflow_sample_assets.json`'s. The hospital_fidelity metric counts
Blueflow assets found in Viper by MAC address — reusing Blueflow's MACs here
would make that metric pass without any integration having run.*

*`just seed` and `just scale` track what they created in
`/srv/viper/TARGET_HOSPITAL_ASSET_COUNT` and refuse to double-run. To rebuild
the environment, `just reset` (clears ALL Viper data), then seed again.*

### Navigate to the justfile
- cd /srv/viper/target-hospital-environment

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

### Running locally (developer machine)

To run against a local Viper checkout instead of the deployed stack:

```

    cd ~/path/to/viper
    npm run db:create-test-api-key --silent | grep '^API_KEY=' | cut -d= -f2- > /tmp/VIPER_API_KEY

    cd -
    VIPER_URL=http://localhost:3000 \
    VIPER_API_KEY_FILE=/tmp/VIPER_API_KEY \
    TARGET_HOSPITAL_STATE_FILE=/tmp/TH_STATE \
    bash init/seed.sh

```

Then the same overrides with `bash init/scale.sh`. The checkout needs postgres
running, migrations applied, and `npm run dev` up (Inngest is not required —
asset creation dispatches no background job). `BATCH_SIZE` (default 50)
controls how many assets ride each bulk request.

### Requirements

- `jq`, `curl`, `just` (all preinstalled on the deployed box)
- expect `just scale` to take a couple of minutes (26 sequential bulk requests)
