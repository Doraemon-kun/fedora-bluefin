#!/usr/bin/bash

set -eoux pipefail

echo "::group:: Revert Bluefin Branding to Vanilla Fedora GNOME"

# Remove everything Bluefin-related that got replaced/overwrote
rm -f /usr/share/pixmaps/fedora-gdm-logo.png
rm -f /usr/share/pixmaps/fedora-logo*.png
rm -f /usr/share/pixmaps/fedora_logo_med.png
rm -f /usr/share/pixmaps/fedora_whitelogo_med.png
rm -f /usr/share/pixmaps/system-logo-white.png
rm -rf /usr/share/pixmaps/faces/bluefin
rm -f /usr/share/icons/hicolor/scalable/places/fedora-logo-sprite.svg
rm -f /usr/share/icons/hicolor/scalable/places/fedora_white_logo.svg
rm -f /usr/share/icons/hicolor/scalable/places/fedora_whitelogo.svg
rm -f /usr/share/icons/hicolor/scalable/places/ublue-*.svg
rm -f /usr/share/icons/hicolor/scalable/actions/ublue-logo-symbolic.svg
rm -rf /usr/share/ublue-os/bluefin-logos
rm -f /usr/share/plymouth/themes/spinner/watermark.png
rm -f /usr/share/plymouth/themes/spinner/silverblue-watermark.png
rm -rf /usr/share/backgrounds/bluefin

# Restore back the Fedora-styled stuff
dnf5 -y swap generic-logos fedora-logos
dnf5 -y reinstall plymouth-theme-spinner

# Removing GNOME gschema from Bluefin and regenerate the gschemas
rm -f /usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override
cat <<EOF > /usr/share/glib-2.0/schemas/zz0-custom-settings.gschema.override
[org.gnome.shell]
disable-extension-version-validation=true
enabled-extensions=['AlphabeticalAppGrid@stuarthayhurst', 'freon@UshakovVasilii_Github.yahoo.com', 'status-area-horizontal-spacing@mathematical.coffee.gmail.com', 'appindicatorsupport@rgcjonas.gmail.com', 'blur-my-shell@aunetx', 'caffeine@patapon.info', 'gsconnect@andyholmes.github.io', 'netspeed@alynx.one', 'just-perfection-desktop@just-perfection', 'simple-weather@romanlefler.com', 'background-logo@fedorahosted.org', 'lockkeys@vaina.lt']

[org.gnome.desktop.wm.preferences]
button-layout=':minimize,maximize,close'

[org.gnome.desktop.interface]
enable-hot-corners=true
clock-show-weekday=true

[org.gnome.desktop.search-providers]
enabled=['io.github.kolunmi.Bazaar.desktop', 'org.gnome.Calculator.desktop']

[org.gnome.desktop.sound]
allow-volume-above-100-percent=true

[org.gnome.desktop.wm.keybindings]
show-desktop=['<Super>d']
switch-applications=['<Super>Tab']
switch-applications-backward=['<Shift><Super>Tab']
switch-windows=['<Alt>Tab']
switch-windows-backward=['<Shift><Alt>Tab']
switch-input-source=['<Super>space']
switch-input-source-backward=['']
unmaximize=['<Super>Down']

[org.gnome.desktop.peripherals.keyboard]
numlock-state=true

[org.gnome.settings-daemon.plugins.power]
power-button-action='interactive'

[org.gtk.Settings.FileChooser]
sort-directories-first=true

[org.gtk.gtk4.Settings.FileChooser]
sort-directories-first=true

[org.gnome.mutter]
center-new-windows=true
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

# Remove Dconf database files
rm -f /etc/dconf/db/distro.d/01-bluefin-folders
rm -f /etc/dconf/db/distro.d/02-bluefin-keybindings
rm -f /etc/dconf/db/distro.d/03-bluefin-ptyxis-palette
rm -f /etc/dconf/db/distro.d/04-bluefin-custom-command-menu
rm -f /etc/dconf/db/distro.d/05-bluefin-searchlight-extension
rm -f /etc/dconf/db/distro.d/locks/01-bluefin-locked-settings
# And update it back
#dconf update

# Remove Terminal stuff at profile (i.e. stop running when open terminal)
rm -f /etc/profile.d/ublue-motd.sh
rm -f /etc/profile.d/ublue-fastfetch.sh

# Other stuff to remove
# App shortcuts
rm -f /usr/share/applications/documentation.desktop
rm -f /usr/share/applications/discourse.desktop
rm -f /usr/share/applications/system-update.desktop
# Firefox prefs
rm -f /usr/share/ublue-os/firefox-config/01-bluefin-global.js
# VS Code settings
rm -rf /etc/skel/.config/Code

# os-release back to Fedora
if [[ -f /usr/lib/os-release ]]; then
    # Name, Pretty name and Hostname
    sed -i 's/NAME="Bluefin"/NAME="Fedora Linux"/g' /usr/lib/os-release
    sed -i 's/PRETTY_NAME="Bluefin/PRETTY_NAME="Fedora Linux/g' /usr/lib/os-release
    sed -i 's/DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="fedora"/' /usr/lib/os-release
    # URLs
    sed -i 's|HOME_URL=".*"|HOME_URL="https://fedoraproject.org/"|g' /usr/lib/os-release
    sed -i 's|DOCUMENTATION_URL=".*"|DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/latest/"|g' /usr/lib/os-release
    sed -i 's|SUPPORT_URL=".*"|SUPPORT_URL="https://ask.fedoraproject.org/"|g' /usr/lib/os-release
    sed -i 's|BUG_REPORT_URL=".*"|BUG_REPORT_URL="https://bugzilla.redhat.com/"|g' /usr/lib/os-release
    # IDs
    sed -i 's/^ID=bluefin/ID=fedora/g' /usr/lib/os-release
    sed -i 's/^VARIANT_ID=.*/VARIANT_ID=fedora-bluefin/g' /usr/lib/os-release
    sed -i 's/^IMAGE_ID=.*/IMAGE_ID=fedora-bluefin/g' /usr/lib/os-release
    # Build Dates
    FEDORA_MAJOR_VERSION=$(grep '^VERSION_ID=' /usr/lib/os-release | cut -d= -f2 | tr -d '"')
    BUILD_DATE=$(date +%Y%m%d)
    ITER_NUM=${BUILD_ITERATION:-0}
    NEW_VERSION="${FEDORA_MAJOR_VERSION}.${BUILD_DATE}.fb.${ITER_NUM}"
    sed -i "s/^VERSION=.*/VERSION=\"${NEW_VERSION}\"/" /usr/lib/os-release
    sed -i "s/^OSTREE_VERSION=.*/OSTREE_VERSION='${NEW_VERSION}'/" /usr/lib/os-release
fi

# Cleanup image-info
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
    sed -i 's/"bluefin"/"fedora-bluefin"/g' /usr/share/ublue-os/image-info.json
    sed -i 's/"bluefin-dx"/"fedora-bluefin-dx"/g' /usr/share/ublue-os/image-info.json
    sed -i 's/"ublue-os"/"doraemon-kun"/g' /usr/share/ublue-os/image-info.json
    sed -i 's/ghcr.io\/ublue-os\/bluefin"/ghcr.io\/doraemon-kun\/fedora-bluefin"/g' /usr/share/ublue-os/image-info.json
    sed -i 's/ghcr.io\/ublue-os\/bluefin-dx"/ghcr.io\/doraemon-kun\/fedora-bluefin-dx"/g' /usr/share/ublue-os/image-info.json
fi

# Clean stuff that DNF left behind
dnf5 -y clean all
rm -rf /var/lib/dnf /var/cache/libdnf5 /run/dnf

echo "::endgroup::"

# Copy from Bluefin's
echo "::group:: Regenerating Initramfs for Plymouth"

KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible -v --add ostree -f "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

echo "::endgroup::"
