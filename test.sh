#!/bin/zsh
# Compiles the core with the self-check in Tests/main.swift and runs it (no Xcode needed).
set -e
cd "$(dirname "$0")"
mkdir -p build
swiftc -O Sources/Core/*.swift Tests/main.swift -o build/selftest
build/selftest
