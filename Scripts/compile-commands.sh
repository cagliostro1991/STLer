#!/bin/zsh
# Writes compile_commands.json so editors (SourceKit-LSP in VS Code, Cursor, Zed) see the same three builds as Scripts/build.sh.
# Without it every file is analysed alone and shows red "cannot find ... in scope" errors. Paths are absolute, so the file stays out of git.
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=$(xcrun --show-sdk-path)
TARGET="$(uname -m)-apple-macos13.0"

python3 - "$PWD" "$SDK" "$TARGET" <<'PY'
import glob, json, sys

root, sdk, target = sys.argv[1:4]
core = sorted(glob.glob("Sources/STLerCore/*.swift"))
# Each group is one swiftc run of build.sh / test.sh; its own files are listed once, the shared core with the CLI group.
groups = [
    ("STLerCLI", core + sorted(glob.glob("Sources/STLerCLI/*.swift")), [], core + sorted(glob.glob("Sources/STLerCLI/*.swift"))),
    ("STLerApp", core + sorted(glob.glob("Sources/STLerApp/*.swift")), ["-parse-as-library"], sorted(glob.glob("Sources/STLerApp/*.swift"))),
    ("SelfCheck", core + ["Tests/SelfCheck/main.swift"], [], ["Tests/SelfCheck/main.swift"]),
]
entries = []
for name, files, flags, listed in groups:
    arguments = ["swiftc", "-sdk", sdk, "-target", target, "-module-name", name, *flags, *files]
    entries += [{"directory": root, "file": file, "arguments": arguments} for file in listed]
with open("compile_commands.json", "w") as out:
    json.dump(entries, out, indent=2)
print(f"compile_commands.json: {len(entries)} files in {len(groups)} groups")
PY
