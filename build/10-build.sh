#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Packages"

# Install packages using dnf5
# Example: dnf5 install -y tmux

# Example using COPR with isolated pattern:
# copr_install_isolated "ublue-os/staging" package-name

# Xwayland dependencies
dnf5 install -y xorg-x11-server-Xwayland libX11 libxcb libXext libXcursor libXrender libXi libXtst libXinerama libXrandr
# GNOME extensions dependencies
dnf5 install -y libsmbios smbios-utils lm_sensors libgda libgda-sqlite gsound
# Opinionated programs
dnf5 install -y waydroid gparted
# fcitx5 supports
dnf5 install -y fcitx5 fcitx5-autostart fcitx5-configtool fcitx5-gtk fcitx5-mozc fcitx5-qt fcitx5-unikey fcitx5-table-extra fcitx5-table-other
# /opt handler
echo > /usr/lib/tmpfiles.d/opt.conf
for dir in /usr/lib/opt/*; do
    [ -e "$dir" ] || continue;
    folder=$(basename "$dir");
    echo "L /var/opt/$folder - - - - /usr/lib/opt/$folder" >> /usr/lib/tmpfiles.d/opt.conf;
done
# Windscribe-related
systemctl enable windscribe-helper.service

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
# Example: systemctl mask unwanted-service

echo "::endgroup::"

echo "::group:: Setup Cosign Key"
# Add custom MOK public key to the certificates directory
if [ -f /ctx/sb.pub ]; then
    mkdir -p /etc/pki/akmods/certs/
    cp /ctx/sb.pub /etc/pki/akmods/certs/sb.pub
fi

# Install the custom cosign public key to the system
if [ -f /ctx/cosign.pub ]; then
    mkdir -p /etc/pki/containers/
    cp /ctx/cosign.pub /etc/pki/containers/doraemon-kun.pub
    mkdir -p /etc/containers/
    cp /ctx/build/policy.json /etc/containers/policy.json
    mkdir -p /etc/containers/registries.d
    cat > /etc/containers/registries.d/doraemon-kun.yaml << 'EOF'
docker:
  ghcr.io/doraemon-kun:
    use-sigstore-attachments: true
EOF
fi
echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
