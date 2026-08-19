# Viper-deploy
- Viper-deploy is a [Carthage layout](https://github.com/hadron/carthage) for deploying [Viper](https://github.com/patch-upgrade/viper) and [Blueflow](https://github.com/virtalabs/blueflow) to AWS.

- **For reproducibility, deploying to AWS is the preferred way to run this stack**. Metrics are tested on an AWS deployment. To support further testing, however, a local Docker target exists for development; see [Running locally on Docker](#running-locally-on-docker).

### How to deploy
*More details pending*
- Install [Carthage](https://github.com/hadron/carthage)
- Create an IAM user with enough permissions to create & manage EC2 instances -- see docs/IAM_role_policy.json for an example
- Have aws_access_key_id and aws_secret_access_key in ~/.aws/config so that Carthage can find it
- Clone this repo, cd to it, and use carthage-runner
- Copy `.env.aws.example` to `/srv/viper-deply/assets/.env`, and fill out environment variables (`ANTHROPIC_API_KEY`, and the pinned `VIPER_VERSION`)

### Instance size considerations
- Viper, Blueflow, & the WHS are happy enough on a t3.medium with a 20GB disk. 
    - The layout is using a t3.large and 40gb disk at time of writing to allow headroom for pulling images / running a couple of containers in the WHS.

- Every merge to [PATCH-UPGRADE/viper](https://github.com/PATCH-UPGRADE/viper) publishes a `sha-<short-commit-sha>` tag alongside `latest` (see its build-publish-image workflow), so any commit on main can be pinned by its first 7 SHA characters.
  - A list of all VIPER packages is on [github](https://github.com/PATCH-UPGRADE/viper/pkgs/container/viper) 

### Running locally on Docker
*AWS is the preferred deployment. This target exists so the IV&V metrics can be developed and debugged on a laptop.*

- `assets/compose.dev.yml` runs VIPER, Inngest's dev server, and Blueflow. VIPER is reached directly at http://localhost:3000 and Blueflow at http://localhost:8000.
- Requirements: Docker, `just`, `jq`

```
cp assets/.env.local.example assets/.env
export VIPER_TARGET=dev
cd assets/ivv_metrics/hospital_fidelity && just start
```

### Other considerations
- Be mindful of Let's Encrypt rate limiting if re-deploying frequently. Consider editing the Caddyfile to use staging certs for development if necessary.
- The `remediation_deployment_time` IV&V metric requires a real `ANTHROPIC_API_KEY` in `assets/.env` before starting the stack -- see assets/ivv_metrics/remediation_deployment_time/README.md.
