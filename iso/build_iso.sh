#!/usr/bin/env bash
set -eoux pipefail

echo "=== Starting LiveCD Preparation ==="

IMAGE_INFO="$(cat /usr/share/ublue-os/image-info.json)"
IMAGE_TAG="$(jq -c -r '."image-tag"' <<<"$IMAGE_INFO")"
IMAGE_REF="$(jq -c -r '."image-ref"' <<<"$IMAGE_INFO")"
INSTALL_IMAGE_REF="${IMAGE_REF##*://}:${IMAGE_TAG}"

# 1. Install Required Dependencies
dnf install -y \
    dracut-live \
    anaconda-live \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    livesys-scripts \
    xorriso \
    isomd5sum \
    grub2-efi-x64-cdboot \
    grub2-pc \
    podman \
    mokutil \
    jq \
    rsync

# 4. Disable Heavy Services & Sleep in LiveCD
systemctl disable rpm-ostree-countme.service tailscaled.service brew-upgrade.timer brew-update.timer brew-setup.service rpm-ostreed-automatic.timer || true
rm -f /etc/xdg/autostart/org.gnome.Software.desktop

mkdir -p /usr/share/glib-2.0/schemas
tee /usr/share/glib-2.0/schemas/zz3-livecd-power.gschema.override <<EOF
[org.gnome.settings-daemon.plugins.power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0

[org.gnome.desktop.session]
idle-delay=uint32 0
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# 5. Fix Anaconda (Windowed Mode & Branding)
# Strip product version so Anaconda falls back to standard windowed mode rather than fullscreen kiosk
sed -i 's/ANACONDA_PRODUCTVERSION=.*/ANACONDA_PRODUCTVERSION=""/' /usr/sbin/liveinst || true
sed -i 's/ANACONDA_PRODUCTVERSION=.*/ANACONDA_PRODUCTVERSION=""/' /usr/bin/liveinst || true

tee /etc/anaconda/profile.d/fedora.conf <<'EOF'
[User Interface]
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
    UserSpoke
hidden_webui_pages =
    anaconda-screen-accounts
EOF


# 6. Construct Modular Kickstart
mkdir -p /usr/share/anaconda/post-scripts/

# Main interactive-defaults
tee /usr/share/anaconda/interactive-defaults.ks <<EOF
ostreecontainer --url=${INSTALL_IMAGE_REF} --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
EOF

# KS: Switch to signed image
tee /usr/share/anaconda/post-scripts/install-configure-upgrade.ks <<EOF
%post --erroronfail
bootc switch --mutate-in-place --transport registry ${INSTALL_IMAGE_REF}
%end
EOF

# KS: Rsync Flatpaks (Bluefin Method)
tee /usr/share/anaconda/post-scripts/install-flatpaks.ks <<'EOF'
%post --erroronfail --nochroot
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP /var/lib/flatpak "$target"
%end
EOF

# KS: SecureBoot Enrollment
mkdir -p /etc/pki/akmods/certs/
curl -Lo /etc/pki/akmods/certs/ublue_pubkey.der https://github.com/ublue-os/akmods/raw/main/certs/public_key.der

tee /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks <<'EOF'
%post --erroronfail --nochroot
set -oue pipefail
if [[ -d "/sys/firmware/efi" ]]; then
    if [[ -f "/etc/pki/akmods/certs/ublue_pubkey.der" ]]; then
        printf 'ublue\nublue\n' | mokutil --timeout -1 || true
        printf 'ublue\nublue\n' | mokutil --import /etc/pki/akmods/certs/ublue_pubkey.der || true
    fi

    # Enroll the custom sb.pub from the deployed system image
    if [[ -f "/etc/pki/akmods/certs/sb.pub" ]]; then
        printf 'ublue\nublue\n' | mokutil --import /etc/pki/akmods/certs/sb.pub || true
    fi
fi
%end
EOF

# 7. System Mounts & Optimizations
# Flatpak read-only protection
echo -e "[Mount]\nType=none\nWhat=/var/lib/flatpak\nWhere=/var/lib/flatpak\nOptions=bind,ro\n[Install]\nWantedBy=local-fs.target" > /etc/systemd/system/var-lib-flatpak.mount
systemctl enable var-lib-flatpak.mount

# 50% RAM tmpfs for /var/tmp
rm -rf /var/tmp || true
mkdir -p /var/tmp
echo -e "[Unit]\nDescription=Larger tmpfs for /var/tmp on live system\n[Mount]\nWhat=tmpfs\nWhere=/var/tmp\nType=tmpfs\nOptions=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota\n[Install]\nWantedBy=local-fs.target" > /etc/systemd/system/var-tmp.mount
systemctl enable var-tmp.mount

mkdir -p /etc/systemd/zram-generator.conf.d/
echo -e "[zram0]\nzram-size = ram\ncompression-algorithm = zstd" > /etc/systemd/zram-generator.conf.d/99-live-zram.conf

# 8. Titanoboa Boot Prep
# Auto-login to GNOME Desktop
sed -i "s/^livesys_session=.*/livesys_session=gnome/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# Stage EFI Binaries
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

echo "=== LiveCD Preparation Complete ==="
