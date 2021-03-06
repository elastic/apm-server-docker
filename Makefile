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
HTTPD ?= apm-server-docker-artifact-server
HTTPD_PORT ?= 8000
DOCKER_ARGS ?= --network host

IMAGE_FLAVORS ?= oss full
FIGLET := pyfiglet -w 160 -f puffy

BUILD_ARTIFACT_PATH ?= apm-server/build/distributions

# Make sure we run local versions of everything, particularly commands
# installed into our virtualenv with pip eg. `docker-compose`.
export PATH := ./bin:./venv/bin:$(PATH)

all: venv image test

test: templates lint
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  $(FIGLET) "test: $(FLAVOR)"; \
	  ./bin/pytest -v --image-flavor=$(FLAVOR) tests/; \
	)
.PHONY: test

# Test a snapshot image, which requires modifying the ELASTIC_VERSION to find the right images.
test-snapshot:
	ELASTIC_VERSION=$(ELASTIC_VERSION)-SNAPSHOT make test


lint: venv
	flake8 tests/
.PHONY: lint

templates: venv
	mkdir -p build/apm-server/config
	touch build/apm-server/config/apm-server.yml
	jinja2 \
	  -D elastic_version=$(ELASTIC_VERSION) \
	  -D url=$(DOWNLOAD_URL_ROOT)/apm-server-$(ELASTIC_VERSION)-linux-x86_64.tar.gz \
	  -D image_flavor=full \
	  templates/Dockerfile.j2 > build/apm-server/Dockerfile-full

	jinja2 \
	  -D elastic_version=$(ELASTIC_VERSION) \
	  -D url=$(DOWNLOAD_URL_ROOT)/apm-server-oss-$(ELASTIC_VERSION)-linux-x86_64.tar.gz \
	  -D image_flavor=oss \
	  templates/Dockerfile.j2 > build/apm-server/Dockerfile-oss

	jinja2 \
	  -D elastic_version=$(ELASTIC_VERSION) \
	  templates/docker-entrypoint.j2 > build/apm-server/docker-entrypoint
	chmod +x build/apm-server/docker-entrypoint

	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  jinja2 \
	    -D version=$(VERSION_TAG) \
	    -D registry=$(REGISTRY) \
	    -D image_flavor=$(FLAVOR) \
	    templates/docker-compose.yml.j2 > docker-compose-$(FLAVOR).yml; \
	  )
.PHONY: templates

image: templates
	$(foreach FLAVOR, $(IMAGE_FLAVORS), \
	  docker build $(DOCKER_FLAGS) -f build/apm-server/Dockerfile-$(FLAVOR) --tag=$(REGISTRY)/apm/apm-server-$(FLAVOR):$(VERSION_TAG) build/apm-server; \
	)
	docker tag $(REGISTRY)/apm/apm-server-full:$(VERSION_TAG) $(REGISTRY)/apm/apm-server:$(VERSION_TAG)

build-from-local-artifacts: templates
	docker run --rm -d --name=$(HTTPD) $(DOCKER_ARGS) \
	-v $(ARTIFACTS_DIR):/mnt \
	  python:3 bash -c 'cd /mnt && python3 -m http.server $(HTTPD_PORT)'
	timeout 120 bash -c 'until curl -s localhost:$(HTTPD_PORT) > /dev/null; do sleep 1; done'

	DOCKER_FLAGS='--network=host' make image || \
	  (docker kill $(HTTPD); false)
	-docker kill $(HTTPD)

release-manager-snapshot:
	ELASTIC_VERSION=$(ELASTIC_VERSION)-SNAPSHOT \
	  DOWNLOAD_URL_ROOT=http://localhost:$(HTTPD_PORT)/$(BUILD_ARTIFACT_PATH) \
	  IMAGE=$(IMAGE)-SNAPSHOT \
	  make build-from-local-artifacts

release-manager-release:
	ELASTIC_VERSION=$(ELASTIC_VERSION) \
	  DOWNLOAD_URL_ROOT=http://localhost:$(HTTPD_PORT)/$(BUILD_ARTIFACT_PATH) \
	  IMAGE=$(IMAGE) \
	  make build-from-local-artifacts

mac-release-snapshot:
	DOCKER_ARGS="--network bridge -p $(HTTPD_PORT):$(HTTPD_PORT)" \
	make release-manager-snapshot

from-snapshot:
	rm -rf ./snapshots
	mkdir -p snapshots/$(BUILD_ARTIFACT_PATH)/$$beat; \
	(cd snapshots/$(BUILD_ARTIFACT_PATH)/$$beat && \
	wget https://snapshots.elastic.co/downloads/apm-server/apm-server-$(ELASTIC_VERSION)-SNAPSHOT-linux-x86_64.tar.gz && \
	wget https://snapshots.elastic.co/downloads/apm-server/apm-server-oss-$(ELASTIC_VERSION)-SNAPSHOT-linux-x86_64.tar.gz); \
	ARTIFACTS_DIR=$$PWD/snapshots make release-manager-snapshot


# Push the image to the dedicated push endpoint at "push.docker.elastic.co"
push: all
	docker tag $(REGISTRY)/apm/apm-server:$(VERSION_TAG) push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)
	docker push push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)
	docker rmi push.$(REGISTRY)/apm/apm-server:$(VERSION_TAG)

# The tests are written in Python. Make a virtualenv to handle the dependencies.
venv: requirements.txt
	@if [ -z $$PYTHON3 ]; then\
	    PY3_MINOR_VER=`python3 --version 2>&1 | cut -d " " -f 2 | cut -d "." -f 2`;\
	    if (( $$PY3_MINOR_VER < 5 )); then\
	        echo "WARNING! Tests require python3 in \$PATH that is >=3.5";\
	        echo "Please install python3.5 or later or explicity define the python3 executable name with \$PYTHON3";\
	        echo "";\
	    else\
	        export PYTHON3="python3.$$PY3_MINOR_VER";\
	    fi;\
	fi;\
	test -d venv || virtualenv --python=$$PYTHON3 venv;\
	pip install -r requirements.txt;\
	touch venv;\

clean: venv
	docker-compose down -v || true
	rm -f docker-compose.yml build/*/Dockerfile build/*/config/*.sh build/*/docker-entrypoint
	rm -rf venv
	find . -name __pycache__ | xargs rm -rf
