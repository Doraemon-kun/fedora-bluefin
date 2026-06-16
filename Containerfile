###############################################################################
# PROJECT NAME CONFIGURATION
###############################################################################
# Name: fedora-bluefin
#
# IMPORTANT: Change "finpilot" above to your desired project name.
# This name should be used consistently throughout the repository in:
#   - Justfile: export image_name := env("IMAGE_NAME", "your-name-here")
#   - README.md: # your-name-here (title)
#   - artifacthub-repo.yml: repositoryID: your-name-here
#   - custom/ujust/README.md: localhost/your-name-here:stable (in bootc switch example)
#
# The project name defined here is the single source of truth for your
# custom image's identity. When changing it, update all references above
# to maintain consistency.
###############################################################################

###############################################################################
# MULTI-STAGE BUILD ARCHITECTURE
###############################################################################
# This Containerfile follows the Bluefin architecture pattern as implemented in
# @projectbluefin/distroless. The architecture layers OCI containers together:
#
# 1. Context Stage (ctx) - Combines resources from:
#    - Local build scripts and custom files
#    - @projectbluefin/common - Desktop configuration shared with Aurora 
#    - @ublue-os/brew - Homebrew integration
#
# 2. Base Image Options:
#    - `ghcr.io/ublue-os/silverblue-main:latest` (Fedora and GNOME)
#    - `ghcr.io/ublue-os/base-main:latest` (Fedora and no desktop 
#    - `quay.io/centos-bootc/centos-bootc:stream10 (CentOS-based)` 
#
# See: https://docs.projectbluefin.io/contributing/ for architecture diagram
###############################################################################

# Declare sample build stage for Renovate
ARG BASE_IMAGE_NAME=bluefin
FROM ghcr.io/ublue-os/bluefin:latest@sha256:2c51b4b8826172fad619b6bb23356b73708aaa7d9e114505161da1b783c33209 AS base-bluefin

# This is just to make sure that these two guys
# will not affect each other in the merge process.
# Please do not remove this comment.
FROM ghcr.io/ublue-os/bluefin-dx:latest@sha256:555e8f4fa634a95919663d8dd549e551ba6872752e57bda0c701b84647509155 AS base-bluefin-dx

# === For building VMware kernel modules ===
FROM base-${BASE_IMAGE_NAME} AS vmware-builder
ARG VMWARE_VERSION="workstation-17.6.3"
RUN rpm-ostree install -y gcc make git wget bison flex elfutils-libelf-devel openssl-devel && \
    KERNEL_VERSION=$(ls /usr/lib/modules | grep -v 'modules.' | tail -n 1) && \
    VERSION=${KERNEL_VERSION%%-*} && \
    REST=${KERNEL_VERSION#*-} && \
    ARCH=${REST##*.} && \
    RELEASE=${REST%.*} && \
    if ! rpm -q kernel-devel-${KERNEL_VERSION} > /dev/null 2>&1; then \
        KOJI_URL="https://kojipkgs.fedoraproject.org/packages/kernel/${VERSION}/${RELEASE}/${ARCH}/kernel-devel-${KERNEL_VERSION}.rpm" && \
        echo "Downloading kernel-devel from: $KOJI_URL" && \
        wget -q "$KOJI_URL" -O /tmp/kernel-devel.rpm && \
        rpm-ostree install -y /tmp/kernel-devel.rpm; \
    else \
        echo "kernel-devel-${KERNEL_VERSION} is already installed, skipping Koji download."; \
    fi && \
    \
    git clone -b ${VMWARE_VERSION} https://github.com/philipl/vmware-host-modules.git /tmp/vmware-modules && \
    cd /tmp/vmware-modules && \
    \
    make VM_UNAME=${KERNEL_VERSION} && \
    make install DESTDIR=/out VM_UNAME=${KERNEL_VERSION}

COPY sb.pub /tmp/sb.pub
RUN --mount=type=secret,id=mok_key \
    KERNEL_VERSION=$(ls /usr/lib/modules | grep -v 'modules.' | tail -n 1) && \
    /usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file sha256 /run/secrets/mok_key /tmp/sb.pub /out/lib/modules/${KERNEL_VERSION}/misc/vmmon.ko && \
    /usr/src/kernels/${KERNEL_VERSION}/scripts/sign-file sha256 /run/secrets/mok_key /tmp/sb.pub /out/lib/modules/${KERNEL_VERSION}/misc/vmnet.ko

# === For building GNOME extensions ===
FROM base-${BASE_IMAGE_NAME} AS gnome-builder
COPY custom/extensions /extensions
RUN rpm-ostree install -y glib2-devel meson sassc cmake dbus-devel gcc make git wget bison \
      flex elfutils-libelf-devel openssl-devel gettext sed optipng nodejs npm gnome-shell libgda \
      libgda-sqlite sqlite && \
    /bin/bash -c "set -eu; shopt -s nullglob; bash /extensions/build-extensions.sh"

# === For weird /opt packages ===
FROM base-${BASE_IMAGE_NAME} AS opt-importer
RUN rm /opt && \
    mkdir /opt && \
    dnf5 install -y "https://windscribe.com/install/desktop/linux_rpm_x64"

# Context stage - combine local and imported OCI container resources
FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY sb.pub /sb.pub
COPY cosign.pub /cosign.pub
# Copy from OCI containers to distinct subdirectories to avoid conflicts
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:1c397ad2fd7210a4b4a6a93ce6babeb6249b504d9cff8fb4bde6b16c6a5735ba /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:2369e2dc70dd8b12828604d22721d1812cd87611661d789e1a0ee2cb123cbe7e /system_files /oci/brew

# Base Image - GNOME included
# Dynamically select the correct base stage based on your GitHub Action matrix
FROM base-${BASE_IMAGE_NAME}

# Add build iterations to be processed
ARG BUILD_ITERATION=0
ENV BUILD_ITERATION=$BUILD_ITERATION

## Alternative base images, no desktop included (uncomment to use):
# FROM ghcr.io/ublue-os/base-main:latest    
# FROM quay.io/centos-bootc/centos-bootc:stream10

## Alternative GNOME OS base image (uncomment to use):
# FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly

# Just in case: Bring the base image variable to the build stage
ARG BASE_IMAGE_NAME

### /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

# Applying VMware kernel module
COPY --from=vmware-builder /out/lib/modules /usr/lib/modules
RUN KERNEL_VERSION=$(ls /usr/lib/modules | grep -v 'modules.' | tail -n 1) && \
    # Update module dependencies mapped to the ostree /usr directory
    depmod -a -b /usr ${KERNEL_VERSION} && \
    # Ensure systemd-udev loads them automatically on boot
    echo "vmmon" > /usr/lib/modules-load.d/vmware.conf && \
    echo "vmnet" >> /usr/lib/modules-load.d/vmware.conf && \
    echo "vmw_vmci" >> /usr/lib/modules-load.d/vmware.conf

# Adding additional extensions
COPY --from=gnome-builder /extensions/built /usr/share/gnome-shell/extensions

# For /opt
COPY --from=opt-importer /opt/ /usr/lib/opt/
# Application-specific /opt
# Windscribe
COPY --from=opt-importer /usr/lib/systemd/system/windscribe-helper.service /usr/lib/systemd/system/
COPY --from=opt-importer /usr/polkit-1/actions/com.windscribe.authhelper.policy /usr/share/polkit-1/actions/
COPY --from=opt-importer /usr/share/applications/windscribe.desktop /usr/share/applications/
COPY --from=opt-importer /usr/share/icons/hicolor/ /usr/share/icons/hicolor/
COPY --from=opt-importer /etc/windscribe/ /etc/windscribe/

### MODIFICATIONS
## Make modifications desired in your image and install packages by modifying the build scripts.
## The following RUN directive mounts the ctx stage which includes:
##   - Local build scripts from /build
##   - Local custom files from /custom
##   - Files from @projectbluefin/common at /oci/common
##   - Files from @projectbluefin/branding at /oci/branding
##   - Files from @ublue-os/artwork at /oci/artwork
##   - Files from @ublue-os/brew at /oci/brew
## Scripts are run in numerical order (10-build.sh, 20-example.sh, etc.)

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /bin/bash -c "set -eu; shopt -s nullglob; for script in /ctx/build/*.sh; do bash \$script; done"

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
