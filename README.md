## Description

This repository contains the official [APM Server][apm-server] Docker image from
[Elastic][elastic].

[apm-server]: https://www.elastic.co/guide/en/apm/server/current/_apm_server.html
[elastic]: https://www.elastic.co/

## Requirements
A full build and test requires:
* Docker
* GNU Make
* Python 3.5 with Virtualenv

## Supported Docker versions

The images have been tested on Docker 17.03.1-ce

## Contributing, issues and testing

Acceptance tests for the image are located in the `test` directory,
and can be invoked with `make test`. Python 3.5 is required to run the
tests. They are based on the
excellent [testinfra](http://testinfra.readthedocs.io/en/latest/),
which is itself based on
the wonderful [pytest](http://doc.pytest.org/en/latest/).

`apm-server-docker` is developed under a test-driven
workflow, so please refrain from submitting patches without test
coverage. If you are not familiar with testing in Python, please
raise an issue instead.

The images are built on [CentOS 7][centos-7].

[centos-7]: https://github.com/CentOS/sig-cloud-instance-images/blob/50281d86d6ed5c61975971150adfd0ede86423bb/docker/Dockerfile
