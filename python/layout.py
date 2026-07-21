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

        class whs_group(AwsSecurityGroup):
            name = 'whs-http'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=8080),
            )
        

        class viper_net(NetworkModel):
            v4_config = V4Config(network="172.31.100.0/24")
            aws_security_groups = ['ssh', 'viper-http', 'blueflow-http', 'whs-http']

        @provides(podman.podman_container_host)
        class hypervisor(MachineModel):
            name = 'hypervisor'
            add_provider(machine_implementation_key, MaybeLocalAwsVm)
            disk_sizes=(40,)
            aws_instance_type = 't3.large'
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
                @setup_task('Prepare compose')
                async def prepare_compose(self):
                    public_ip = str(self.host.network_links['eth0'].merged_v4_config.public_address)
                    async with self.host.filesystem_access() as fs:
                        viper_path = fs / 'srv' /'viper'
                        compose_path = Path("./assets/compose-aws.yml")
                        viper_path.mkdir(parents=True, exist_ok=True)
                        (viper_path / "compose-aws.yml").write_text(compose_path.read_text())
                        (viper_path / ".env").write_text(
                            f"BETTER_AUTH_URL=http://{public_ip}:3000\n"
                            f"NEXT_PUBLIC_APP_URL=http://{public_ip}\n"
                            )

                @setup_task('Start Viper & Blueflow')
                async def start_viper(self):
                    await self.run_command('bash', '-c',
                                            'cd /srv/viper && podman-compose -f compose-aws.yml --env-file .env systemd -a create-unit')
                    await self.run_command('bash', '-c',
                                            'cd /srv/viper && podman-compose -f compose-aws.yml --env-file .env systemd -a register')
                    await self.run_command('systemctl', '--user', 'enable', '--now', 'podman-compose@viper')

            class handle_integration(MachineCustomization):
                @setup_task("Copy & load blueflow sample assets")
                async def copy_blueflow_assets(self):
                    blueflow_assets_path = Path("./assets/blueflow_sample_assets.json")
                    async with self.host.filesystem_access() as fs:
                        dest_path = fs / 'srv' / 'viper' / 'blueflow-init' / "assets.json"
                        if not dest_path.exists(): # Blueflow's create_assets is not idempotent
                            dest_path.write_text(blueflow_assets_path.read_text())
                            await self.run_command('bash', '-c',
                                                    'cd /srv/viper && '
                                                    'while [ "$(podman inspect -f \'{{.State.Health.Status}}\' viper_blueflow_1 2>/dev/null)" != "healthy" ]; do '
                                                    'sleep 2;'
                                                    'done && '
                                                    'podman-compose -f compose-aws.yml exec -T blueflow /app/.venv/bin/python project/manage.py create_assets --filepath /blueflow-init/assets.json')

                @setup_task("Create Viper credentials")
                async def create_viper_credentials(self):
                    await self.run_command("bash", "-c",
                                           "cd /srv/viper && podman-compose -f compose-aws.yml exec -T viper npm run db:create-test-api-key --silent | grep '^API_KEY=' | cut -d= -f2- > blueflow_integration_key")
                    await self.run_command("bash", "-c",
                                           "cd /srv/viper && podman-compose -f compose-aws.yml exec -T viper npm run db:create-blueflow-integration --silent | grep '^INTEGRATION_TOKEN=' | cut -d= -f2- >> blueflow_integration_token")

                @setup_task("Create test integration")
                async def create_integration(self):
                    await self.run_command("bash", "-c",
                                            'cd /srv/viper && podman-compose -f compose-aws.yml exec -T \
                                            -e VIPER_API_URL=http://localhost:3000/api/v1 \
                                            -e BLUEFLOW_URL=http://blueflow:8000 \
                                            -e VIPER_API_KEY="$(cat blueflow_integration_key)" \
                                            -e VIPER_CALLBACK_URL="http://viper:3000/api/v1/assets/integrationUpload/$(cat blueflow_integration_token)" \
                                            viper npm run test:integration')

        class whs(MachineModel):
            name = 'whs'
            add_provider(machine_implementation_key, dependency_quote(podman.PodmanContainer))
            add_provider(oci.oci_container_image, 'ghcr.io/patch-upgrade/whs:latest')
            podman_options = ('--privileged', '-i', '-t', '-p8080:8080', '-vwhs:/srv/whs')

    return await ainjector(layout)
