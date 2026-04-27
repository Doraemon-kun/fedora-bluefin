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

# Clean stuff that DNF left behind
dnf5 -y clean all
rm -rf /var/lib/dnf /var/cache/libdnf5 /run/dnf

# Removing GNOME gschema from Bluefin and regenerate the gschemas
rm -f /usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas

# Remove Dconf database files
rm -f /etc/dconf/db/distro.d/01-bluefin-folders
rm -f /etc/dconf/db/distro.d/02-bluefin-keybindings
rm -f /etc/dconf/db/distro.d/03-bluefin-ptyxis-palette
rm -f /etc/dconf/db/distro.d/04-bluefin-custom-command-menu
rm -f /etc/dconf/db/distro.d/05-bluefin-searchlight-extension
rm -f /etc/dconf/db/distro.d/locks/01-bluefin-locked-settings
# And update it back
dconf update

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
    # Change Pretty Name
    sed -i 's/PRETTY_NAME="Bluefin"/PRETTY_NAME="Fedora Linux"/g' /usr/lib/os-release
    # Change Bug Report URL back to Fedora
    sed -i 's/BUG_REPORT_URL="https:\/\/github.com\/ublue-os\/bluefin\/issues"/BUG_REPORT_URL="https:\/\/bugzilla.redhat.com\/"/g' /usr/lib/os-release
    # Change Home URL back to Fedora
    sed -i 's/HOME_URL="https:\/\/projectbluefin.io"/HOME_URL="https:\/\/fedoraproject.org\/"/g' /usr/lib/os-release
    # Clean up the Name
    sed -i 's/NAME="Bluefin"/NAME="Fedora Linux"/g' /usr/lib/os-release
fi

# Cleanup image-info
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
    sed -i 's/"bluefin"/"fedora-bluefin"/g' /usr/share/ublue-os/image-info.json
fi

echo "::endgroup::"
