#!/bin/bash
# Bouwt Raster, zet hem in ~/Applications en start hem daar.
# macOS 27 kent het bundle-id van menubalkicoontjes alleen voor apps in /Applications of ~/Applications.
# Vanuit build/ gebruikt het de procesnaam, en dan verbergt een menubalkbeheerder (Menubalk, Bartender)
# het icoon. Dit script installeert daarom naar ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
osascript -e 'tell application id "nl.jimlindenburg.raster" to quit' 2>/dev/null || true
for _ in $(seq 1 50); do
  [ "$(osascript -e 'application id "nl.jimlindenburg.raster" is running' 2>/dev/null)" = "true" ] || break
  sleep 0.1
done
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Raster.app"
ditto build/Raster.app "$HOME/Applications/Raster.app"
open "$HOME/Applications/Raster.app"
echo "$HOME/Applications/Raster.app"
