# vim: set ft=make :
####################
### custom-apps.just
####################
## Example application installation commands
## These are simplified examples adapted from Bluefin

# Install default applications via Homebrew
[group('Apps')]
install-default-apps:
    #!/usr/bin/env bash
    echo "Installing default applications via Homebrew..."
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile

# Install development tools via Homebrew
[group('Apps')]
install-dev-tools:
    #!/usr/bin/env bash
    echo "Installing development tools via Homebrew..."
    brew bundle --file /usr/share/ublue-os/homebrew/development.Brewfile

# Install fonts via Homebrew
[group('Apps')]
install-fonts:
    #!/usr/bin/env bash
    echo "Installing fonts via Homebrew..."
    brew bundle --file /usr/share/ublue-os/homebrew/fonts.Brewfile

# Install all Brewfiles at once
[group('Apps')]
install-all-brew:
    #!/usr/bin/env bash
    echo "Installing all applications from Brewfiles..."
    brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile
    brew bundle --file /usr/share/ublue-os/homebrew/development.Brewfile
    brew bundle --file /usr/share/ublue-os/homebrew/fonts.Brewfile

# Install JetBrains Toolbox for managing JetBrains IDEs
[group('Apps')]
install-jetbrains-toolbox:
    #!/usr/bin/env bash
    echo "Installing JetBrains Toolbox..."
    pushd "$(mktemp -d)"
    echo "Fetching latest version..."
    curl -sSfL -o releases.json "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
    BUILD_VERSION=$(jq -r '.TBA[0].build' ./releases.json)
    DOWNLOAD_LINK=$(jq -r '.TBA[0].downloads.linux.link' ./releases.json)
    CHECKSUM_LINK=$(jq -r '.TBA[0].downloads.linux.checksumLink' ./releases.json)
    echo "Installing JetBrains Toolbox ${BUILD_VERSION}"
    curl -sSfL -O "${DOWNLOAD_LINK}"
    curl -sSfL "${CHECKSUM_LINK}" | sha256sum -c
    tar zxf jetbrains-toolbox-"${BUILD_VERSION}".tar.gz
    mkdir -p $HOME/.local/share/JetBrains/ToolboxApp/
    mv jetbrains-toolbox-"${BUILD_VERSION}"/* $HOME/.local/share/JetBrains/ToolboxApp/
    popd
    echo "Launching JetBrains Toolbox..."
    $HOME/.local/share/JetBrains/ToolboxApp/bin/jetbrains-toolbox

# Shortcut for install-jetbrains-toolbox
[group('Apps')]
jetbrains-toolbox:
    @ujust install-jetbrains-toolbox

# Install a Flatpak application from Flathub
[group('Apps')]
install-flatpak APP_ID:
    #!/usr/bin/bash
    echo "Installing {{ APP_ID }} from Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub {{ APP_ID }}

# Example: Install VSCode via Flatpak
[group('Apps')]
install-vscode:
    ujust install-flatpak com.visualstudio.code

# Example: Install GIMP via Flatpak
[group('Apps')]
install-gimp:
    ujust install-flatpak org.gimp.GIMP

[group('Apps')]
install-vmware:
    #!/usr/bin/env bash
    set -e

    echo "Creating rootful distrobox container 'vmware'..."
    distrobox create -r -i quay.io/fedora/fedora:latest -n vmware -H ~/.distrobox/vmware --volume /lib/modules:/lib/modules:ro -ap "fontconfig dejavu-sans-fonts dejavu-sans-mono-fonts google-noto-sans-fonts alsa-lib libX11 libxcb libXext libXcursor libXrender libXi libXtst libXinerama libXrandr mesa-dri-drivers mesa-libGL mesa-vulkan-drivers kmod"

    echo "Updating fontconfig cache inside the container..."
    distrobox enter -r vmware -- fc-cache -f -v

    echo ""
    echo "==============================================================================="
    echo " Environment is ready! You can now finish the VMware installation manually."
    echo "==============================================================================="
    echo " 1. Download VMware Workstation Pro 17.6.4 from the Broadcom portal."
    echo " 2. Enter your new container with: distrobox enter --root vmware"
    echo " 3. Run the downloaded VMware .bundle installer as root."
    echo " 4. Start the network/USB services by running:"
    echo "      sudo vmware-networks --start"
    echo "      sudo vmware-usbarbitrator"
    echo " 5. Run 'sudo vmware' to launch VMware Workstation."
    echo ""
    echo " IMPORTANT: Every time you restart the system or stop the container, you must "
    echo " re-run step 4 inside the container before starting VMware."
    echo "==============================================================================="
