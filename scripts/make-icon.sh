#!/bin/bash
# Tekent het app-icoon opnieuw (scripts/make-icon.swift) en maakt er Resources/AppIcon.icns van.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
swift scripts/make-icon.swift Resources/AppIcon-1024.png >/dev/null
mkdir "$WORK/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon-1024.png --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon-1024.png --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o Resources/AppIcon.icns
echo Resources/AppIcon.icns
