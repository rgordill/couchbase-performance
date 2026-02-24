# Makefile for Couchbase Performance Testing Client

IMAGE_NAME ?= couchbase-perftest
IMAGE_TAG ?= latest
REGISTRY ?= quay.io/rgordill
BUILDER ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
# libcouchbase tarball: libcouchbase-<version>_<os>_<arch>.tar (from GitHub releases)
version ?= 3.3.18
os ?= rhel10
arch ?= x86_64

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the container image (version, os, arch; untar into /usr/local)
	$(BUILDER) build \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		--build-arg version=$(version) \
		--build-arg os=$(os) \
		--build-arg arch=$(arch) \
		-f Containerfile .

.PHONY: push
push: ## Push image to registry
	$(BUILDER) push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: run
run: ## Run a quick test
	$(BUILDER) run --rm \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/scripts/run-pillowfight.sh

.PHONY: test-write-heavy
test-write-heavy: ## Run write-heavy benchmark
	$(BUILDER) run --rm \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/scripts/benchmark.sh write-heavy

.PHONY: test-read-heavy
test-read-heavy: ## Run read-heavy benchmark
	$(BUILDER) run --rm \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/scripts/benchmark.sh read-heavy

.PHONY: test-mixed
test-mixed: ## Run mixed workload benchmark
	$(BUILDER) run --rm \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/scripts/benchmark.sh mixed

.PHONY: test-stress
test-stress: ## Run stress test
	$(BUILDER) run --rm \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/scripts/benchmark.sh stress

.PHONY: shell
shell: ## Start interactive shell in container
	$(BUILDER) run --rm -it \
		-e CB_HOST=couchbase-cluster \
		-e CB_USER=performance-user \
		-e CB_PASSWORD=P3rf0rm@nce! \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash

.PHONY: ping
ping: ## Test connectivity to Couchbase
	$(BUILDER) run --rm \
		$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		cbc-ping \
		-U couchbase://couchbase-cluster/performance \
		-u performance-user \
		-P P3rf0rm@nce!

.PHONY: clean
clean: ## Remove local image
	$(BUILDER) rmi $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) || true

.DEFAULT_GOAL := help
