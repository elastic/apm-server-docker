from .fixtures import apm_server


def test_group_properties(Group, apm_server):
    group = Group(apm_server.name)
    assert group.exists
    assert group.gid == 1000


def test_user_properties(User, apm_server):
    user = User(apm_server.name)
    assert user.uid == 1000
    assert user.gid == 1000
    assert user.group == apm_server.name
    assert user.home == '/usr/share/%s' % apm_server.name
    assert user.shell == '/bin/bash'
