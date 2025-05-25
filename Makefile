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
.SECONDARY:
.NOTPARALLEL: .env working info/working.md

include .env
WORKING_CONTAINER ?= fedora-toolbox-working-container
FED_IMAGE         := registry.fedoraproject.org/fedora-toolbox

HEADING1 := \#
HEADING2 := $(HEADING1)$(HEADING1)



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
	buildah config --env LANG="C.UTF-8" --env CPPFLAGS="-D_DEFAULT_SOURCE" $(WORKING_CONTAINER)

default: working build-deps

# Create the working container
working: info/working.md
info/working.md: 
	echo '##[ $@ ]##'
	mkdir -p $(dir $@)
	printf "$(HEADING2) %s\n\n" "Working Container" | tee $@
	printf "The Toolbox is built from %s" "$(shell cat latest/fedora-toolbox.json | jq -r '.Labels.name')" | tee -a $@
	printf ", version %s\n" $(FROM_VERSION) | tee -a $@
	printf "\nPulled from registry:  %s\n" $(FROM_REGISTRY) | tee -a $@

DEPS := gcc gcc-c++ \
		gettext-devel \
		glibc-devel \
		libevent-devel \
		ncurses-devel \
		openssl-devel \
		perl-devel \
		pkgconf \
		readline-devel \
		zlib-devel

build-deps: $(addprefix dep-install-,$(DEPS))

$(addprefix dep-install-,$(COMMON_DEPS)):
	@item=$(patsubst dep-install-%,%,$@); \
	echo "Installing common dependency $$item..."; \
	buildah run $(WORKING_CONTAINER) dnf install \
		--allowerasing \
		--skip-unavailable \
		--skip-broken \
		--no-allow-downgrade \
		-y \
		$$item





