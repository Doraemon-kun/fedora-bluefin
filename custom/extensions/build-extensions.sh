#!/usr/bin/bash
set -eoux pipefail

mkdir -p /extensions/built/

# Alphabetical App Grid
make build -C "/extensions/AlphabeticalAppGrid@stuarthayhurst/"
unzip -o "/extensions/AlphabeticalAppGrid@stuarthayhurst/build/AlphabeticalAppGrid@stuarthayhurst.shell-extension.zip" -d "/extensions/built/AlphabeticalAppGrid@stuarthayhurst"
glib-compile-schemas --strict "/extensions/built/AlphabeticalAppGrid@stuarthayhurst/schemas"

# Freon
cp -r "/extensions/freon@UshakovVasilii_Github.yahoo.com/freon@UshakovVasilii_Github.yahoo.com" "/extensions/built/freon@UshakovVasilii_Github.yahoo.com"
glib-compile-schemas --strict "/extensions/built/freon@UshakovVasilii_Github.yahoo.com/schemas"

# Status Area Horizontal Spacing
cp -r "/extensions/status-area-horizontal-spacing@mathematical.coffee.gmail.com/status-area-horizontal-spacing@mathematical.coffee.gmail.com" "/extensions/built/status-area-horizontal-spacing@mathematical.coffee.gmail.com"
glib-compile-schemas --strict "/extensions/built/status-area-horizontal-spacing@mathematical.coffee.gmail.com/schemas"

# Net Speed
cp -r "/extensions/netspeed@alynx.one" "/extensions/built/netspeed@alynx.one"

# Just Perfection
cd "/extensions/just-perfection-desktop@just-perfection"
glib-compile-resources --sourcedir src/data src/data/resources.gresource.xml
gnome-extensions pack src --force --podir="../po" --extra-source="data/resources.gresource" --extra-source="lib"
unzip -o just-perfection-desktop@just-perfection.shell-extension.zip -d "/extensions/built/just-perfection-desktop@just-perfection"
glib-compile-schemas --strict "/extensions/built/just-perfection-desktop@just-perfection/schemas"

# SimpleWeather
cd "/extensions/simple-weather@romanlefler.com"
rm -rf node_modules
npm install --cache /tmp/npm-cache
PATH="$(pwd)/node_modules/.bin:$PATH" make out
cp -r dist/build "/extensions/built/simple-weather@romanlefler.com"

# Background Logo
cd "/extensions/background-logo@fedorahosted.org"
meson setup build
meson compile -C build zip-file
unzip -o build/background-logo@fedorahosted.org.shell-extension.zip -d "/extensions/built/background-logo@fedorahosted.org"
glib-compile-schemas --strict "/extensions/built/background-logo@fedorahosted.org/schemas"

# Lock Keys
cp -r "/extensions/lockkeys@vaina.lt/lockkeys@vaina.lt" "/extensions/built/lockkeys@vaina.lt"

# Bluetooth Battery Meter
cd "/extensions/Bluetooth-Battery-Meter@maniacx.github.com"
gnome-extensions pack ./ --extra-source=icons/ --extra-source=lib/ --extra-source=preferences/ --extra-source=ui/ --extra-source=script/ --podir=po --force
unzip -o Bluetooth-Battery-Meter@maniacx.github.com.shell-extension.zip -d "/extensions/built/Bluetooth-Battery-Meter@maniacx.github.com"
glib-compile-schemas --strict "/extensions/built/Bluetooth-Battery-Meter@maniacx.github.com/schemas"

# Battery Health Charging
cd "/extensions/Battery-Health-Charging@maniacx.github.com"
gnome-extensions pack ./ --extra-source=devices/ --extra-source=icons/ --extra-source=lib/ --extra-source=resources/ --extra-source=preferences/ --extra-source=tool/ --extra-source=ui/ --podir=po --force
unzip -o Battery-Health-Charging@maniacx.github.com.shell-extension.zip -d "/extensions/built/Battery-Health-Charging@maniacx.github.com"
glib-compile-schemas --strict "/extensions/built/Battery-Health-Charging@maniacx.github.com/schemas"

# Kimpanel
cd "/extensions/kimpanel@kde.org"
mkdir build && cd build
cmake ..
make clean
make build-zip
unzip -o kimpanel@kde.org.zip -d "/extensions/built/kimpanel@kde.org"

# Copyous
mkdir -p /tmp/pnpm-setup && cd /tmp/pnpm-setup
npm install pnpm --cache /tmp/npm-cache
PATH="/tmp/pnpm-setup/node_modules/.bin:$PATH"
export CI=true
export npm_config_loglevel=silent
cd "/extensions/copyous@boerdereinar.dev"
jq 'del(.scripts.install)' package.json > package.json.tmp && mv package.json.tmp package.json
cat <<EOF > pnpm-workspace.yaml
allowBuilds:
  esbuild: true
  "@parcel/watcher": true
reporter: 'silent'
EOF
echo "node-linker=hoisted" > .npmrc
echo "confirmModulesPurge=false" >> .npmrc
pnpm install --store-dir=./.pnpm-store --reporter=append-only --no-frozen-lockfile
RELEASE=1 make build
unzip -o "dist/copyous@boerdereinar.dev.zip" -d "/extensions/built/copyous@boerdereinar.dev"
glib-compile-schemas --strict "/extensions/built/copyous@boerdereinar.dev/schemas"
