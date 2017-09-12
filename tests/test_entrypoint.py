from .fixtures import apm_server
from .helpers import run


def test_entrypoint_with_args(apm_server):
    cmd = run(apm_server, "-c %s -configtest" % apm_server.config_file.path)
    assert cmd.returncode == 0


def test_entrypoint_with_apm_server_subcommand(apm_server):
    cmd = run(apm_server, 'help')
    assert cmd.returncode == 0
    assert 'Usage:' in cmd.stdout.decode()
    assert apm_server.name in cmd.stdout.decode()


def test_entrypoint_with_apm_server_subcommand_and_longopt(apm_server):
    cmd = run(apm_server, 'setup --help')
    assert cmd.returncode == 0
    assert b'This command does initial setup' in cmd.stdout


def test_entrypoint_with_abitrary_command(apm_server):
    cmd = run(apm_server, "echo Hello World!")
    assert cmd.returncode == 0
    assert cmd.stdout == b'Hello World!'


def test_entrypoint_with_explicit_apm_server_binary(apm_server):
    cmd = run(apm_server, '%s --version' % apm_server.name)
    assert cmd.returncode == 0
    assert apm_server.version in cmd.stdout.decode()
