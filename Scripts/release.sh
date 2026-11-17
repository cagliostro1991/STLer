#!/bin/zsh
# Builds a release archive in dist/: STLer.app and the stler CLI, plus a checksum. Needs a clean `make test` first.
# Usage: Scripts/release.sh   (the version comes from the VERSION file)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
NAME="STLer-$VERSION-macos"
make build
rm -rf "dist/$NAME" "dist/$NAME.zip" "dist/$NAME.zip.sha256"
mkdir -p "dist/$NAME"
cp -R build/STLer.app "dist/$NAME/"
cp build/stler "dist/$NAME/"
cp README.md LICENSE "dist/$NAME/"
(cd dist && ditto -c -k --norsrc --noextattr --keepParent "$NAME" "$NAME.zip" && shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256")
rm -rf "dist/$NAME"
echo "dist/$NAME.zip"
cat "dist/$NAME.zip.sha256"
