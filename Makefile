SHELL=/bin/bash

export ELASTIC_VERSION := $(shell ./bin/elastic-version)

ifdef STAGING_BUILD_NUM
export VERSION_TAG := $(ELASTIC_VERSION)-$(STAGING_BUILD_NUM)
DOWNLOAD_URL_ROOT ?= https://staging.elastic.co/$(VERSION_TAG)/downloads/apm-server
else
export VERSION_TAG := $(ELASTIC_VERSION)
DOWNLOAD_URL_ROOT ?= https://artifacts.elastic.co/downloads/apm-server
endif

REGISTRY ?= docker.elastic.co

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
	docker build --tag=$(REGISTRY)/apm/apm-server:$(VERSION_TAG) build/apm-server

release-manager-snapshot: templates
	DOWNLOAD_URL_ROOT=http://localhost:8000/build/release-artifacts/apm-server/build/upload make templates
	docker build --network=host --tag=$(REGISTRY)/apm/apm-server:$(VERSION_TAG) build/apm-server

release-manager-release: templates
	DOWNLOAD_URL_ROOT=http://localhost:8000/build/release-artifacts/apm-server/build/upload make templates
	docker build --network=host --tag=$(REGISTRY)/apm/apm-server:$(VERSION_TAG) build/apm-server

# Push the images to the dedicated push endpoint at "push.docker.elastic.co"
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
