#!/bin/zsh
# Builds the CLI (build/styler) and the settings app (build/STyLer.app) with swiftc; no Xcode needed.
set -e
cd "$(dirname "$0")"
APP=build/STyLer.app
rm -rf build && mkdir -p $APP/Contents/MacOS

swiftc -O Sources/Core/*.swift Sources/CLI/main.swift -o build/styler
swiftc -O -parse-as-library Sources/Core/*.swift Sources/App/*.swift -o $APP/Contents/MacOS/STyLer

swiftc -O Tools/make-icon.swift -o build/make-icon
mkdir -p $APP/Contents/Resources
build/make-icon $APP/Contents/Resources/AppIcon.icns

cat > $APP/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.pavlo.STyLer</string>
<key>CFBundleName</key><string>STyLer</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>STyLer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>STyLer reads which folder is open in Finder to render its model icons.</string>
</dict></plist>
PLIST

codesign -f -s - $APP
codesign -f -s - build/styler
echo "built build/styler and $APP"
