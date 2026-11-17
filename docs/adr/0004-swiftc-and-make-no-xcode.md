# 0004. Build with swiftc and a Makefile

- Status: accepted
- Date: 2026-11-17

## Context

Only the Command Line Tools are installed. `swift build` fails to link `PackageDescription` for the manifest; `@State` needs the `SwiftUIMacros` plugin that ships with Xcode.

## Decision

Compile with `swiftc` from `Scripts/build.sh`, assemble the `.app` by hand (`Sources/STLerApp/Info.plist`, `iconutil` on `icons/macOS/AppIcon.iconset`), sign ad-hoc, expose `make build|test|clean`. No SwiftPM manifest, no XCTest. SwiftUI code avoids `@State`; transient UI state lives in the `ObservableObject`.

## Consequences

- Zero setup for contributors with only CLT.
- Other Macs see Gatekeeper warnings for the ad-hoc signed app (build from source or right-click Open).
- Core is compiled into both executables; no module/`public` boundaries.
