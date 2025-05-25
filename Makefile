SHELL       := /usr/bin/bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --silent
MAKEFLAGS += --jobs=$(shell nproc)
unexport MAKEFLAGS
.SUFFIXES:            # Delete the default suffixes
.ONESHELL:            # All lines of the recipe will be given to a single invocation of the shell
.DELETE_ON_ERROR:     # Delete intermediate files if recipe fails

include .env
WORKING_CONTAINER ?= fedora-toolbox-working-container
FED_IMAGE         := registry.fedoraproject.org/fedora-toolbox

latest/fedora-toolbox.json:
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	skopeo inspect docker://${FED_IMAGE}:latest | jq '.' > $@

.env: latest/fedora-toolbox.json
	echo '##[ $@ ]##'
	FROM_REGISTRY=$$(cat $< | jq -r '.Name'); \
	FROM_VERSION=$$(cat $< | jq -r '.Labels.version'); \
	FROM_NAME=$$(cat $< | jq -r '.Labels.name'); \
	printf "FROM_NAME=%s\n" "$$FROM_NAME" | tee $@; \
	printf "FROM_REGISTRY=%s\n" "$$FROM_REGISTRY" | tee -a $@; \
	printf "FROM_VERSION=%s\n" "$$FROM_VERSION" | tee -a $@; \
	buildah pull "$$FROM_REGISTRY:$$FROM_VERSION" &> /dev/null; \
	echo -n "WORKING_CONTAINER=" | tee -a .env; \
	buildah from "$${FROM_REGISTRY}:$${FROM_VERSION}" | tee -a .env; \
	echo -n "NPROC=" | tee -a .env; \
	buildah run $(WORKING_CONTAINER) nproc | tee -a .env


