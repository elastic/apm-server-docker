import subprocess
import os


def run(apm_server, command, elevated_privileges=False):
    image = 'docker.elastic.co/apm/%s:%s' % (apm_server.name, apm_server.tag)

    if elevated_privileges:
        cli = 'docker run -u root --rm --interactive %s %s' % (image, command)
    else:
        cli = 'docker run --rm --interactive %s %s' % (image, command)

    result = subprocess.run(cli, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    result.stdout = result.stdout.rstrip()
    return result
