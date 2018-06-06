from .fixtures import apm_server


def test_labels(apm_server):
    labels = apm_server.docker_metadata['Config']['Labels']
    assert labels['org.label-schema.name'] == 'apm-server'
    assert labels['org.label-schema.schema-version'] == '1.0'
    assert labels['org.label-schema.url'] == 'https://www.elastic.co/solutions/apm'
    assert labels['org.label-schema.vcs-url'] == 'https://github.com/elastic/apm-server-docker'
    assert labels['org.label-schema.vendor'] == 'Elastic'
    assert labels['org.label-schema.version'] == apm_server.tag
    if apm_server.flavor == 'oss':
        assert labels['license'] == 'Apache-2.0'
    else:
        assert labels['license'] == 'Elastic License'
