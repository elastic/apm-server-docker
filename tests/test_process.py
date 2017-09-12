from .fixtures import apm_server


def test_process_is_pid_1(apm_server):
    assert apm_server.process.pid == 1


def test_process_is_running_as_the_correct_user(apm_server):
    assert apm_server.process.user == apm_server.name


def test_process_was_started_with_the_foreground_flag(apm_server):
    assert '-e' in apm_server.process['args']
