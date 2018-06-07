import json
import os
import pytest
import yaml
from subprocess import run, PIPE


@pytest.fixture()
def apm_server(Process, File, TestinfraBackend, Command):
    class ApmServer:
        def __init__(self):
            name = TestinfraBackend.get_hostname()
            home = os.path.join(os.sep, 'usr', 'share', name)

            self.name = name
            self.version = run('./bin/elastic-version', stdout=PIPE).stdout.decode().strip()
            self.process = Process.get(comm=name)
            self.home_dir = File(home)
            self.data_dir = File(os.path.join(home, 'data'))
            self.config_dir = File(home)
            self.log_dir = File(os.path.join(home, 'logs'))
            self.kibana_dir = File(os.path.join(home, 'kibana'))
            self.binary_file = File(os.path.join(home, name))
            self.config_file = File(os.path.join(home, '%s.yml' % name))

            # Use the "export config" subcommand to find out what the final
            # configuration will be. This gives a nice, normalized data structure
            # for making assertions about the config.
            export_config = Command.run('%s --path.config=%s export config' %
                                        (self.binary_file.path, self.config_dir.path))
            self.config = yaml.load(export_config.stdout)

            if 'STAGING_BUILD_NUM' in os.environ:
                self.tag = '%s-%s' % (self.version, os.environ['STAGING_BUILD_NUM'])
            else:
                self.tag = self.version

            self.flavor = pytest.config.getoption('--image-flavor')
            if self.flavor != 'full':
                self.image = 'docker.elastic.co/apm/%s-%s:%s' % (self.name, self.flavor, self.tag)
            else:
                self.image = 'docker.elastic.co/apm/%s:%s' % (self.name, self.tag)

            self.docker_metadata = json.loads(
                run(['docker', 'inspect', self.image], stdout=PIPE).stdout.decode())[0]

    return ApmServer()
