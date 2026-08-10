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

### Other considerations
- Be mindful of Let's Encrypt rate limiting if re-deploying frequently. Consider editing the Caddyfile to use staging certs for development if necessary.
- The remediation_deployment_time IV&V metric requires a real `ANTHROPIC_API_KEY` exported in the shell before starting the stack -- see assets/ivv_metrics/remediation_deployment_time/README.md.
- The target-hospital-environment harness seeds a representative 1,500-asset fleet directly into Viper -- see assets/target-hospital-environment/README.md.
