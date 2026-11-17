# macOS gotchas (each one was hit while building STLer)

## Icons and Finder
- A third-party `QLThumbnailProvider` is never called for STL; the system provider wins even with a custom UTI (ADR 0001).
- `NSWorkspace.setIcon` bumps the file's modification date. Restore it (ADR 0007). `setIcon(nil, ...)` too.
- Custom icon = resource fork + `FinderInfo` byte 8 bit `0x04` (`kHasCustomIcon`). `NSWorkspace.icon(forFile:)` from a CLI may still return the generic icon; judge by Finder.
- Finder caches the icons of an already open folder: leave and re-enter it, or `killall Finder` as a last resort. `qlmanage -r cache` resets the Quick Look cache.
- Embedded thumbnails of `.3mf` (slicer plate previews) are shown by the system; a custom icon overrides them.

## Build and language
- `swift build` fails on Command Line Tools only (manifest does not link `PackageDescription`).
- `@State` is a macro in the current SDK and needs the Xcode-only `SwiftUIMacros` plugin: keep UI state in an `ObservableObject`.
- `SCNRenderer.snapshot(...)` returns a non-optional `NSImage`.
- `while let x = ... where cond` stops the loop at the first non-match; filter inside the body instead.
- Top-level code only works in a file named `main.swift`; the SwiftUI app needs `-parse-as-library`.
- stdout is block-buffered when redirected to a file (agent logs): `setvbuf(stdout, nil, _IOLBF, 0)`.

## Filesystem
- APFS is case-insensitive by default: `rm render.swift` deleted `Render.swift`, and `Sources/stler` and `Sources/STLer` are the same directory. Name directories apart by more than case.
- `unzip` mangles non-ASCII member names (`×` became `+ù`); use `bsdtar -xOf archive member`.

## Automation (TCC)
- `NSAppleScript` must run on the main thread. First use pops an Automation prompt per binary; the app needs `NSAppleEventsUsageDescription`.
- A process started by `launchd` has its own identity, so the prompt appears again for the installed `~/.local/bin/stler`.

## Shell and tooling
- In zsh `log` is a builtin: use `/usr/bin/log show ...`.
- macOS has no `timeout`; use `perl -e 'alarm N; exec @ARGV' cmd`.
- `qlmanage -t` can hang; test thumbnails through `QLThumbnailGenerator` with an alarm.
- `screencapture` grabs the whole screen, including private windows. Ask the user for a screenshot instead.
- Editing files with `str.index(anchor)` on a string that occurs twice truncates the file; use unique anchors or rewrite the file.
