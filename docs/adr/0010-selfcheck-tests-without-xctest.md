# 0010. Self-check tests without XCTest

- Status: accepted
- Date: 2026-11-17

## Context

XCTest needs Xcode. The logic worth testing (config validation, depth, 3MF transforms, signature, mtime preservation) is small.

## Decision

`Tests/SelfCheck/main.swift` is a plain executable compiled with the core by `Scripts/test.sh`; `check(condition, message)` prints ok/FAIL and exits non-zero on failure. It uses temp files and a temp `STLER_CONFIG`, and ends with an end-to-end render/skip/reset run.

## Consequences

- Runs anywhere the CLT are installed, in seconds.
- No parallelism or fixtures; the settings window and LaunchAgent are not covered.
