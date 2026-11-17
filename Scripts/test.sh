#!/bin/zsh
# Compiles the core with the self-check in Tests/SelfCheck and runs it; no Xcode needed.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O Sources/STLerCore/*.swift Tests/SelfCheck/main.swift -o build/selftest
STLER_CONFIG="$(mktemp -u)" build/selftest
