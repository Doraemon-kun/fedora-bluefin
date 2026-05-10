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
