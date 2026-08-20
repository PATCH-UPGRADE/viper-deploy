from carthage import *
from carthage import ssh, oci, podman
from carthage.modeling import *
from carthage.ansible import *
from carthage.network import V4Config
from carthage_aws import *
from pathlib import Path

@inject(ainjector=AsyncInjector)
async def build_layout(ainjector):
    class layout(CarthageLayout):
        layout_name = 'viper'
        domain = 'viper-xi.app'

        add_provider(ssh.SshKey)
        
        class ssh_group(AwsSecurityGroup):
            name = 'ssh'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=22),
            )

        class viper_group(AwsSecurityGroup):
            name = 'viper-http'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=3000),
            )

        class blueflow_group(AwsSecurityGroup):
            name = 'blueflow-http'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=8000),
            )

        class proxy_group(AwsSecurityGroup):
            name = 'proxy'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=80),
                SgRule(cidr='0.0.0.0/0',
                       port=443),
            )

        class viper_net(NetworkModel):
            v4_config = V4Config(network="10.10.1.0/24")
            aws_security_groups = ['ssh', 'viper-http', 'blueflow-http', 'proxy']

        class viper_address(VpcAddress):
            name = 'viper'

        @provides(podman.podman_container_host)
        class hypervisor(MachineModel):
            name = 'hypervisor'
            add_provider(machine_implementation_key, MaybeLocalAwsVm)
            disk_sizes = (40,)
            aws_instance_type = 't3.large'
            cloud_init = True
            add_provider(InjectionKey("aws_ami"),
            image_provider(owner=debian_ami_owner, name='debian-13-amd64-*'))

            class net_config(NetworkConfigModel):
                add('eth0', mac=None, net=InjectionKey('viper_net'),
                    v4_config=V4Config(public_address=injector_access(viper_address)))

            class install_packages(FilesystemCustomization):
                @setup_task('Install packages')
                async def install_podman(self):
                    await self.run_command('apt', 'update')
                    await self.run_command('apt', '-y', 'install', 'git', 'podman', 'containers-storage', 'podman-compose', 'acl', 'just', 'jq')

            class prepare_assets(MachineCustomization):
                @setup_task('Prepare assets')
                async def prepare_assets(self):
                    async with self.host.filesystem_access() as fs:
                        viper_path = fs / 'srv' /'viper-deploy'
                        viper_path.mkdir(parents=True, exist_ok=True)

                    await self.run_command('git', 'clone', 'https://github.com/PATCH-UPGRADE/viper-deploy.git', '/srv/viper-deploy')

                    # Both compose files read assets/.env, which is gitignored; -n keeps a hand-edited one
                    await self.run_command('cp', '-n', '/srv/viper-deploy/assets/.env.aws.example', '/srv/viper-deploy/assets/.env')

                    # Not currently used; handling starting & integration via Justfile for first IV&V metric
                    await self.run_command('cp', '/srv/viper-deploy/assets/viper.service', '/etc/systemd/system/viper.service')

        class whs(MachineModel):
            name = 'whs'
            add_provider(machine_implementation_key, dependency_quote(podman.PodmanContainer))
            add_provider(oci.oci_container_image, 'ghcr.io/patch-upgrade/whs:latest')
            podman_options = ('--privileged', '-i', '-t', '-p8080:8080', '-vwhs:/srv/whs')

    return await ainjector(layout)
