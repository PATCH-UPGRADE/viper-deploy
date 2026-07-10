from tracemalloc import DomainFilter

from carthage import *
from carthage import ssh
from carthage.modeling import *
from carthage.ansible import *
from carthage.network import V4Config
from carthage_aws import *

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

        class web_group(AwsSecurityGroup):
            name = 'http-https'
            ingress_rules = (
                SgRule(cidr='0.0.0.0/0',
                       port=80),
                SgRule(cidr='0.0.0.0/0',
                       port=443),
            )

        class viper_net(NetworkModel):
            v4_config = V4Config(network="172.31.100.0/24")
            aws_security_groups = ['ssh', 'http-https']

        class viper_hypervisor(MachineModel):
            name = 'viper'
            add_provider(machine_implementation_key, MaybeLocalAwsVm)
            disk_sizes=(40,)
            aws_instance_type = 't3.large'
            cloud_init = True
            add_provider(InjectionKey("aws_ami"),
            image_provider(owner=debian_ami_owner, name='debian-13-amd64-*'))

            class net_config(NetworkConfigModel):
                add('eth0', mac=None, net=InjectionKey('viper_net'))

    return await ainjector(layout)
            