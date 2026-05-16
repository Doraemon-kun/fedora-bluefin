# vim: set ft=make :
#######################
### custom-system.just
#######################
## Example system configuration commands
## These are simplified examples adapted from Bluefin

# Run a system benchmark (requires stress-ng from Homebrew)
[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        echo "stress-ng is not installed."
        if command -v brew &>/dev/null; then
            if gum confirm "Install stress-ng via Homebrew?" ; then
                brew install stress-ng
                brew link stress-ng
            else
                exit 0
            fi
        else
            echo "Please install stress-ng to run benchmarks."
            exit 1
        fi
    fi
    echo 'Running a 1 minute benchmark...'
    pushd $(mktemp -d) > /dev/null
    stress-ng --matrix 0 -t 1m --times
    popd > /dev/null

# Configure docker and libvirt groups for development
[group('System')]
configure-dev-groups:
    #!/usr/bin/pkexec bash
    CURRENT_USER="{{ `id -un` }}"
    echo "Adding $CURRENT_USER to docker and libvirt groups..."

    # Ensure groups exist in /etc/group
    for group in docker libvirt; do
        if ! grep -q "^$group:" /etc/group; then
            echo "Adding $group to /etc/group"
            grep "^$group:" /usr/lib/group | tee -a /etc/group > /dev/null
        fi
        usermod -aG $group $CURRENT_USER
    done

    echo "Groups configured. Log out and back in for changes to take effect."

# Redefine toggle-devmode to work with my naming scheme
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    set -e
    IMAGE_INFO_FILE="${IMAGE_INFO_FILE:-/usr/share/ublue-os/image-info.json}"
    IMAGE_NAME="$(jq -rc '."image-name"' "${IMAGE_INFO_FILE}")"
    IMAGE_REF="$(jq -rc '."image-ref"' "${IMAGE_INFO_FILE}" | sed "s/.*ghcr/ghcr/")"
    CURRENT_IMAGE="${IMAGE_REF}:$(jq -rc '."image-tag"' "${IMAGE_INFO_FILE}")"
    set +e

    if grep -q -E -e "dx$" <<< "${IMAGE_NAME}" ; then
        gum confirm "Would you like to disable developer mode?" || exit 0
        echo "Rebasing to a non developer image"
        NEW_IMAGE="$(sed "s/\-dx//" <<< $CURRENT_IMAGE)"
        pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"
        exit 0
    fi

    gum confirm "Would you like to enable developer mode?" || exit 0
    echo "Rebasing to a developer image"
    NEW_IMAGE="$(sed "s/${IMAGE_NAME}/${IMAGE_NAME}-dx/" <<< "${CURRENT_IMAGE}")"
    pkexec bootc switch --enforce-container-sigpolicy "${NEW_IMAGE}"

    if gum confirm "Do you want to also install the default development flatpaks?" ; then
        ADD_DEVMODE=1 ujust install-system-flatpaks 0 1
    fi
    if gum confirm "Do you want to install extra monospace fonts?" ; then
        brew bundle install --file=/usr/share/ublue-os/homebrew/fonts.Brewfile
    fi
    echo "Use ujust dx-group to add your user to the correct groups and complete the installation after rebooting into the development image"

# Clean up container images and volumes
[group('Maintenance')]
clean-containers:
    #!/usr/bin/bash
    echo "Cleaning up Podman containers, images, and volumes..."
    podman system prune -af
    podman volume prune -f
    echo "Cleanup complete!"

# Update system and reboot if needed
[group('Maintenance')]
update-and-reboot:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    echo "Updating system..."
    sudo bootc upgrade
    if gum confirm "Reboot now to apply updates?"; then
        systemctl reboot
    else
        echo "Reboot later to apply updates."
    fi
