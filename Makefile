#
# Makefile for Docker multiplatform building
#
# Requires:    bash, docker-cli, docker-buildx-plugin, regctl
#

# Image info
PUBLIC_REPO  = docker.io
LOCAL_REPO   = anas:5000
IMAGE_NAME   = dagui0/my-hello
IMAGE_TAG    = 20251121-1

# Release
# For publishing to public repo, use `make PUSH_PUBLIC=yes SET_LATEST=yes`.
#PUSH_PUBLIC  = yes
#SET_LATEST   = yes
#RM_OS_TAGS   = yes

# Develop
# Wheather to push to public repo
PUSH_PUBLIC  = no
# Whether to set 'latest' tag also
SET_LATEST   = no
# Wheather to remove OS specific tags after merging
RM_OS_TAGS   = yes

# Build hosts
CONTEXT         =
BUILDER         = crossbuilder
CONTEXT_WINDOWS = vwin
define BUILDER_CONFIG
anas ssh://anas linux/arm64,linux/arm/v7,linux/arm/v6
xvms ssh://xvms linux/amd64,linux/amd64/v2,linux/riscv64,linux/ppc64,linux/ppc64le,linux/s390x, linux/386, linux/loong64
endef
export BUILDER_CONFIG

# Supported platforms
LINUX_ARCHS   = linux/amd64,linux/arm64,linux/arm/v7
TARGETS       =	build/linux-$(IMAGE_TAG) \
                build/windows-ltsc2019-$(IMAGE_TAG) \
                build/windows-ltsc2022-$(IMAGE_TAG) \
                build/windows-ltsc2025-$(IMAGE_TAG)

# Apply local environemnt
-include local.mk

# Specify all the files for tracking changes
LINUX_FILES   = hello.txt hello.sh
WINDOWS_FILES = hello.txt hello.cmd

.PHONY: merge clean create-$(BUILDER)

merge: build/merge-local-$(IMAGE_TAG) build/merge-public-$(IMAGE_TAG)

clean:
	@echo "This action does not remove already pushed images."
	rm -rf $(TARGETS)

create-$(BUILDER):
	printf '%s\n' "$$BUILDER_CONFIG" | \
	LOCAL_REPO="$(LOCAL_REPO)" \
	CONTEXT="$(CONTEXT)" \
	Makefile.bin/create-builder.sh $(BUILDER)

build/merge-public-$(IMAGE_TAG): $(TARGETS)
	if [ "$(PUSH_PUBLIC)" = "yes" ]; then \
	    temp_tags=; \
	    for t in $(TARGETS); do \
	        temp_tags="$$temp_tags $$(basename $$t)"; \
	    done; \
	    REPO="$(PUBLIC_REPO)" \
	    IMAGE_NAME="$(IMAGE_NAME)" \
	    IMAGE_TAG="$(IMAGE_TAG)" \
	    SET_LATEST="$(SET_LATEST)" \
	    RM_OS_TAGS="$(RM_OS_TAGS)" \
	    CONTEXT="$(CONTEXT)" \
	    BUILDER="$(BUILDER)" \
	    LINUX_ARCHS="$(LINUX_ARCHS)" \
	    Makefile.bin/merge-tags.sh $$temp_tags && \
	    mkdir -p build && touch $@; \
	else \
	    mkdir -p build && touch $@; \
	fi

build/merge-local-$(IMAGE_TAG): $(TARGETS)
	temp_tags=; \
	for t in $(TARGETS); do \
	    temp_tags="$$temp_tags $$(basename $$t)"; \
	done; \
	REPO="$(LOCAL_REPO)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$(IMAGE_TAG)" \
	SET_LATEST="$(SET_LATEST)" \
	RM_OS_TAGS="$(RM_OS_TAGS)" \
	CONTEXT="$(CONTEXT)" \
	BUILDER="$(BUILDER)" \
	LINUX_ARCHS="$(LINUX_ARCHS)" \
	Makefile.bin/merge-tags.sh $$temp_tags && \
	mkdir -p build && touch $@

build/linux-$(IMAGE_TAG): Dockerfile $(LINUX_FILES)
	PUBLIC_REPO="$(PUBLIC_REPO)" \
	LOCAL_REPO="$(LOCAL_REPO)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$$(basename $@)" \
	PUSH_PUBLIC="$(PUSH_PUBLIC)" \
	SET_LATEST="$(SET_LATEST)" \
	CONTEXT="$(CONTEXT)" \
	BUILDER="$(BUILDER)" \
	BASE_IMAGE=alpine \
	BASE_VERSION=3.22.2 \
	Makefile.bin/run-buildx.sh \
	  -f Dockerfile \
	  --platform="$(LINUX_ARCHS)" && \
	mkdir -p build && touch $@

build/windows-ltsc2025-$(IMAGE_TAG): Dockerfile.windows $(WINDOWS_FILES)
	PUBLIC_REPO="$(PUBLIC_REPO)" \
	LOCAL_REPO="$(LOCAL_REPO)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$$(basename $@)" \
	PUSH_PUBLIC="$(PUSH_PUBLIC)" \
	SET_LATEST="$(SET_LATEST)" \
	CONTEXT="$(CONTEXT_WINDOWS)" \
	BASE_IMAGE=nanoserver \
	BASE_VERSION=ltsc2025 \
	Makefile.bin/run-build.sh \
	  -f Dockerfile.windows && \
	mkdir -p build && touch $@

build/windows-ltsc2022-$(IMAGE_TAG): Dockerfile.windows $(WINDOWS_FILES) \
			build/windows-ltsc2025-$(IMAGE_TAG) # for sequential build on single host
	PUBLIC_REPO="$(PUBLIC_REPO)" \
	LOCAL_REPO="$(LOCAL_REPO)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$$(basename $@)" \
	PUSH_PUBLIC="$(PUSH_PUBLIC)" \
	SET_LATEST="$(SET_LATEST)" \
	CONTEXT="$(CONTEXT_WINDOWS)" \
	BASE_IMAGE=nanoserver \
	BASE_VERSION=ltsc2022 \
	Makefile.bin/run-build.sh \
	  -f Dockerfile.windows && \
	mkdir -p build && touch $@

build/windows-ltsc2019-$(IMAGE_TAG): Dockerfile.windows $(WINDOWS_FILES) \
			build/windows-ltsc2022-$(IMAGE_TAG) # for sequential build on single host
	PUBLIC_REPO="$(PUBLIC_REPO)" \
	LOCAL_REPO="$(LOCAL_REPO)" \
	IMAGE_NAME="$(IMAGE_NAME)" \
	IMAGE_TAG="$$(basename $@)" \
	PUSH_PUBLIC="$(PUSH_PUBLIC)" \
	SET_LATEST="$(SET_LATEST)" \
	CONTEXT="$(CONTEXT_WINDOWS)" \
	BASE_IMAGE=nanoserver \
	BASE_VERSION=ltsc2019 \
	Makefile.bin/run-build.sh \
	  -f Dockerfile.windows && \
	mkdir -p build && touch $@
