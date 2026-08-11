# Viper-deploy
- Viper-deploy is a [Carthage layout](https://github.com/hadron/carthage) for deploying [Viper](https://github.com/patch-upgrade/viper) and [Blueflow](https://github.com/virtalabs/blueflow) to AWS.

### How to deploy
*More details pending*
- Install [Carthage](https://github.com/hadron/carthage)
- Create an IAM user with enough permissions to create & manage EC2 instances -- see docs/IAM_role_policy.json for an example
- Have aws_access_key_id and aws_secret_access_key in ~/.aws/config so that Carthage can find it
- Clone this repo, cd to it, and use carthage-runner

### Instance size considerations
- Viper, Blueflow, & the WHS are happy enough on a t3.medium with a 20GB disk. 
    - The layout is using a t3.large and 40gb disk at time of writing to allow headroom for pulling images / running a couple of containers in the WHS.

### Pinning the VIPER version
- By default the stack runs `ghcr.io/patch-upgrade/viper:latest`. To pin an exact version, export `VIPER_VERSION` before starting the stack:

```
export VIPER_VERSION=sha-cd4fab8
podman-compose -f /srv/viper/compose-aws.yml pull viper
podman-compose -f /srv/viper/compose-aws.yml up -d
```

- Every merge to [PATCH-UPGRADE/viper](https://github.com/PATCH-UPGRADE/viper) publishes a `sha-<short-commit-sha>` tag alongside `latest` (see its build-publish-image workflow), so any commit on main can be pinned by its first 7 SHA characters.
- Note that `latest` only updates on `pull` -- a running box keeps its cached image until you pull explicitly, so pinning is the reliable way to know exactly what is deployed.

### Other considerations
- Be mindful of Let's Encrypt rate limiting if re-deploying frequently. Consider editing the Caddyfile to use staging certs for development if necessary.
- The remediation_deployment_time IV&V metric requires a real `ANTHROPIC_API_KEY` exported in the shell before starting the stack -- see assets/ivv_metrics/remediation_deployment_time/README.md.