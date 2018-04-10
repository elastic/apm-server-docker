from .fixtures import apm_server
from .helpers import run
import os


def test_binary_file_version(Command, apm_server):
    version_string = '%s version %s (amd64), libbeat %s' \
                     % (apm_server.name, apm_server.version, apm_server.version)
    command = Command('%s --version' % apm_server.binary_file.path)
    assert command.stdout.strip() == version_string


def test_binary_file_permissions(apm_server):
    assert apm_server.binary_file.user == 'root'
    assert apm_server.binary_file.group == apm_server.name
    assert apm_server.binary_file.mode == 0o0750


def test_config_file_permissions(apm_server):
    assert apm_server.config_file.user == 'root'
    assert apm_server.config_file.group == apm_server.name
    assert apm_server.config_file.mode == 0o0640


def test_config_dir_permissions(apm_server):
    assert apm_server.config_dir.user == 'root'
    assert apm_server.config_dir.group == apm_server.name
    assert apm_server.config_dir.mode == 0o0750


def test_data_dir_permissions(apm_server):
    assert apm_server.data_dir.user == 'root'
    assert apm_server.data_dir.group == apm_server.name
    assert apm_server.data_dir.mode == 0o0770


def test_kibana_dir_permissions(apm_server):
    assert apm_server.kibana_dir.user == 'root'
    assert apm_server.kibana_dir.group == apm_server.name
    assert apm_server.kibana_dir.mode == 0o0750


def test_log_dir_permissions(apm_server):
    assert apm_server.log_dir.user == 'root'
    assert apm_server.log_dir.group == apm_server.name
    assert apm_server.log_dir.mode == 0o0770


def test_suid_bit_removed(apm_server):
    cmd = run(apm_server, "find / -xdev -perm -4000", True)
    assert cmd.returncode == 0
    assert not cmd.stdout
    assert not cmd.stderr
