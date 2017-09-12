import os
import pytest
from subprocess import run, PIPE

version = run('./bin/elastic-version', stdout=PIPE).stdout.decode().strip()


@pytest.fixture()
def apm_server(Process, File, TestinfraBackend, Command):
    class ApmServer:
        def __init__(self):
            name = TestinfraBackend.get_hostname()
            home = os.path.join(os.sep, 'usr', 'share', name)

            self.name = name
            self.process = Process.get(comm=name)
            self.home_dir = File(home)
            self.data_dir = File(os.path.join(home, 'data'))
            self.config_dir = File(home)
            self.log_dir = File(os.path.join(home, 'logs'))
            self.kibana_dir = File(os.path.join(home, 'kibana'))
            self.binary_file = File(os.path.join(home, name))
            self.config_file = File(os.path.join(home, '%s.yml' % name))
            self.version = version

            if 'STAGING_BUILD_NUM' in os.environ:
                self.tag = '%s-%s' % (version, os.environ['STAGING_BUILD_NUM'])
            else:
                self.tag = version

    return ApmServer()
