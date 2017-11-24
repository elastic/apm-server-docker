SHELL := /bin/bash

export ELASTIC_VERSION := $(shell ./bin/elastic-version)

ifdef STAGING_BUILD_NUM
  export VERSION_TAG := $(ELASTIC_VERSION)-$(STAGING_BUILD_NUM)
  DOWNLOAD_URL_ROOT ?= https://staging.elastic.co/$(VERSION_TAG)/downloads/apm-server
else
  export VERSION_TAG := $(ELASTIC_VERSION)
  DOWNLOAD_URL_ROOT ?= https://artifacts.elastic.co/downloads/apm-server
endif

REGISTRY ?= docker.elastic.co
IMAGE ?= $(REGISTRY)/apm/apm-server:$(VERSION_TAG)
HTTPD ?= apm-server-docker-artifact-server

# Make sure we run local versions of everything, particularly commands
# installed into our virtualenv with pip eg. `docker-compose`.
export PATH := ./bin:./venv/bin:$(PATH)

all: venv image docker-compose.yml test

test: lint
	bin/pytest -v tests/
.PHONY: test

lint: venv
	flake8 tests/
.PHONY: lint

templates: venv
	mkdir -p build/apm-server/config
	touch build/apm-server/config/apm-server.yml
	jinja2 \
	  -D version=$(ELASTIC_VERSION) \
	  -D url=$(DOWNLOAD_URL_ROOT)/apm-server-$(ELASTIC_VERSION)-linux-x86_64.tar.gz \
          templates/Dockerfile.j2 > build/apm-server/Dockerfile

	jinja2 \
	  -D version=$(ELASTIC_VERSION) \
	  templates/docker-entrypoint.j2 > build/apm-server/docker-entrypoint
	chmod +x build/apm-server/docker-entrypoint

	jinja2 \
	  -D version=$(VERSION_TAG) \
	  -D registry=$(REGISTRY) \
	  templates/docker-compose.yml.j2 > docker-compose.yml
.PHONY: templates

image: templates
	docker build --tag=$(IMAGE) build/apm-server

# Clones elastic/apm-server and builds from master
image-dev: templates
	jinja2 templates/Dockerfile.dev.j2 > build/apm-server/Dockerfile
	docker build --tag=apm-server:dev build/apm-server

build-from-local-artifacts: templates
	docker run --rm -d --name=$(HTTPD) --network=host \
	-v $(ARTIFACTS_DIR):/mnt \
	  python:3 bash -c 'cd /mnt && python3 -m http.server'
	timeout 120 bash -c 'until curl -s localhost:8000 > /dev/null; do sleep 1; done'

	docker build --network=host -t $(IMAGE) build/apm-server || \
	  (docker kill $(HTTPD); false)
	-docker kill $(HTTPD)

release-manager-snapshot:
	ELASTIC_VERSION=$(ELASTIC_VERSION)-SNAPSHOT \
	  DOWNLOAD_URL_ROOT=http://localhost:8000/apm-server/build/upload \
	  IMAGE=$(IMAGE)-SNAPSHOT \
	  make build-from-local-artifacts

release-manager-release:
	ELASTIC_VERSION=$(ELASTIC_VERSION) \
	  DOWNLOAD_URL_ROOT=http://localhost:8000/apm-server/build/upload \
	  IMAGE=$(IMAGE) \
	  make build-from-local-artifacts

# Push the image to the dedicated push endpoint at "push.docker.elastic.co"
push: all
	docker tag $(REGISTRY)/apm/apm-server:$(VERSION_TAG) push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)
	docker push push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)
	docker rmi push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)

venv: requirements.txt
	test -d venv || virtualenv --python=python3.5 venv
	pip install -r requirements.txt
	touch venv

clean: venv
	docker-compose down -v || true
	rm -f docker-compose.yml build/*/Dockerfile build/*/config/*.sh build/*/docker-entrypoint
	rm -rf venv
	find . -name __pycache__ | xargs rm -rf
