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

        class whs_group(AwsSecurityGroup):
            name = 'whs-http'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=8080),
            )
        

        class viper_net(NetworkModel):
            v4_config = V4Config(network="172.31.100.0/24")
            aws_security_groups = ['ssh', 'viper-http', 'whs-http']

        @provides(podman.podman_container_host)
        class hypervisor(MachineModel):
            name = 'hypervisor'
            add_provider(machine_implementation_key, MaybeLocalAwsVm)
            disk_sizes=(30,)
            aws_instance_type = 't3.medium'
            cloud_init = True
            add_provider(InjectionKey("aws_ami"),
            image_provider(owner=debian_ami_owner, name='debian-13-amd64-*'))

            class net_config(NetworkConfigModel):
                add('eth0', mac=None, net=InjectionKey('viper_net'))

            class install_packages(FilesystemCustomization):
                @setup_task('Install packages')
                async def install_podman(self):
                    await self.run_command('apt', 'update')
                    await self.run_command('apt', '-y', 'install', 'git', 'podman', 'containers-storage', 'podman-compose', 'acl')

            class handle_viper(MachineCustomization):
                @setup_task('Pull Viper & handle env')
                async def prepare_viper(self):
                    async with self.host.filesystem_access() as fs:
                        viper_path = fs / 'srv' /'viper'
                        if not viper_path.exists():
                            viper_path.mkdir(parents=True, exist_ok=False)
                            await self.run_command('git', 'clone', 'https://github.com/PATCH-UPGRADE/viper.git', '/srv/viper')
                        else:
                            await self.run_command('bash', '-c',
                                                   'cd /srv/viper && git pull')
                    
                    # Avoid long build times on AWS
                    await self.run_command('podman', 'pull', 'ghcr.io/patch-upgrade/viper:latest')

                    # TODO: Handle this better. Should we mount .envs and/or handle via github secrets for this deployment type?
                    await self.run_command('cp', '/srv/viper/.env.example', '/srv/viper/.env')
                    await self.run_command('cp', '/srv/viper/.db.env.example', '/srv/viper/.db.env')

                @setup_task('Start Viper')
                async def start_viper(self):
                    await self.run_command('bash', '-c',
                                            'cd /srv/viper && podman-compose systemd -a create-unit')
                    await self.run_command('bash', '-c',
                                            'cd /srv/viper && podman-compose systemd -a register')
                    await self.run_command('systemctl', '--user', 'enable', '--now', 'podman-compose@viper')

            class handle_blueflow(MachineCustomization):
                pass

            class handle_integration(MachineCustomization):
                pass

        class whs(MachineModel):
            name = 'whs'
            add_provider(machine_implementation_key, dependency_quote(podman.PodmanContainer))
            add_provider(oci.oci_container_image, 'ghcr.io/patch-upgrade/whs:latest')
            podman_options = ('--privileged', '-i', '-t', '-p8080:8080', '-vwhs:/srv/whs')

    return await ainjector(layout)
