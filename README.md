# Viper-deploy
- Viper-deploy is a [Carthage layout](https://github.com/hadron/carthage) for deploying [Viper](https://github.com/patch-upgrade/viper) and [Blueflow](https://github.com/virtalabs/blueflow) to AWS.

### Instance size considerations
- Viper, Blueflow, & the WHS are happy enough on a t3.medium with a 20GB disk. 
    - The layout is using a t3.large and 40gb disk at time of writing to allow headroom for pulling images / running a couple of containers in the WHS.