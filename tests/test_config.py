from .fixtures import apm_server


def test_config_file_passes_config_test(Command, apm_server):
    configtest = '%s -c %s -configtest' % (apm_server.binary_file.path, apm_server.config_file.path)
    Command.run_expect([0], configtest)


def test_apm_server_listens_on_all_interfaces(apm_server):
    configured_host = apm_server.config['apm-server']['host']
    assert configured_host == '0.0.0.0:8200'


def test_elasticsearch_output_points_to_elasticsearch_host(apm_server):
    configured_hosts = apm_server.config['output']['elasticsearch']['hosts']
    assert configured_hosts == ['elasticsearch:9200']
