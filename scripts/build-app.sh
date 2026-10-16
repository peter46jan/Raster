#!/bin/bash
# Bouwt build/Raster.app en ondertekent hem. Standaard ad-hoc ("-"); geef met RASTER_SIGN_IDENTITY een vaste
# identiteit mee (bijv. een Apple Development-certificaat). Met een vaste identiteit blijft de
# Toegankelijkheid-toestemming na een nieuwe build gelden.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Raster
APP=build/Raster.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Raster "$APP/Contents/MacOS/Raster"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "${RASTER_SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
echo "$APP"
