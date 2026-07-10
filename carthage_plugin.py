from carthage import *
from carthage.modeling import CarthageLayout
from . import layout

@inject(injector=Injector)
def carthage_plugin(injector):
    injector.add_provider(InjectionKey(CarthageLayout), layout.build_layout)
