import subprocess
import os


def run(apm_server, command):
    image = 'docker.elastic.co/apm/%s:%s' % (apm_server.name, apm_server.tag)
    cli = 'docker run --rm --interactive %s %s' % (image, command)
    result = subprocess.run(cli, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    result.stdout = result.stdout.rstrip()
    return result
