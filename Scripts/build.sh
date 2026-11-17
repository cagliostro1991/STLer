#!/bin/zsh
# Builds build/stler (CLI) and build/STLer.app (settings window) with swiftc; no Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/STLer.app
rm -rf build
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources

swiftc -O Sources/STLerCore/*.swift Sources/STLerCLI/*.swift -o build/stler
swiftc -O -parse-as-library Sources/STLerCore/*.swift Sources/STLerApp/*.swift -o $APP/Contents/MacOS/STLer

iconutil -c icns icons/macOS/AppIcon.iconset -o $APP/Contents/Resources/AppIcon.icns
cp Sources/STLerApp/Info.plist $APP/Contents/Info.plist
VERSION=$(cat VERSION)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" $APP/Contents/Info.plist
cp Sources/STLerApp/Resources/3DBenchy.* $APP/Contents/Resources/

codesign -f -s - $APP
codesign -f -s - build/stler
echo "built build/stler and $APP"
