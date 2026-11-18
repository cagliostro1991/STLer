#!/bin/zsh
# Type-checks the three builds without linking, lints the formatting and checks whitespace. Faster than `make build`; run it before committing.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== CLI";   swiftc -typecheck Sources/STLerCore/*.swift Sources/STLerCLI/*.swift
echo "== app";   swiftc -typecheck -parse-as-library Sources/STLerCore/*.swift Sources/STLerApp/*.swift
echo "== tests"; swiftc -typecheck Sources/STLerCore/*.swift Tests/SelfCheck/main.swift

echo "== format"; swift format lint --strict --recursive Sources Tests Tools

echo "== whitespace"
if grep -rnE ' +$' --include='*.swift' --include='*.sh' Sources Tests Scripts Tools; then
    echo "trailing whitespace found" >&2
    exit 1
fi
echo "check passed"
