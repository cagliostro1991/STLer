# macOS gotchas (each one was hit while building STLer)

## Icons and Finder
- A third-party `QLThumbnailProvider` is never called for STL; the system provider wins even with a custom UTI (ADR 0001).
- `NSWorkspace.setIcon` bumps the file's modification date. Restore it (ADR 0007). `setIcon(nil, ...)` too.
- Custom icon = resource fork + `FinderInfo` byte 8 bit `0x04` (`kHasCustomIcon`). `NSWorkspace.icon(forFile:)` from a CLI may still return the generic icon; judge by Finder.
- Finder caches the icons of an already open folder: leave and re-enter it, or `killall Finder` as a last resort. `qlmanage -r cache` resets the Quick Look cache.
- Embedded thumbnails of `.3mf` (slicer plate previews) are shown by the system; a custom icon overrides them.

## Rendering
- ModelIO derives smooth normals from welded vertices when an STL has zero facet normals, so a cube comes out as one flat hexagon. We compute flat normals ourselves (`FlatGeometry`).
- A light on the camera axis lights every face of an isometric cube equally. Keep the key light off-axis (upper left of the camera).
- Opacity through SceneKit material transparency shows hidden faces through the model; apply it at composite time instead.

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

## `follow` has to notice files added to the folder that is already open

Comparing only the folder path means a file dropped into the open folder is never seen. `FollowState` also compares the folder's modification date (a new or removed entry changes it; icon writes are xattrs and do not). Files added deeper than the top level change a subfolder's date, not the top one, so they are picked up the next time the folder is reopened.


## The signature is not proof of an icon

Extended attributes do not always travel together: a copy to another volume, through iCloud or via an archive can keep `dev.stler.sig` and lose the resource fork or the Finder "custom icon" flag. Trusting the signature alone left such files grey for good. `IconBatch` treats a file as up to date only when the signature matches and `Signature.hasIcon` (flag in `com.apple.FinderInfo`, byte 8 bit `0x04`, plus a non-empty `com.apple.ResourceFork`) agrees.

## Icons on the bundled samples break codesign
STLer sets custom icons (resource fork and Finder info) on any model file in its scope, including the samples in `Sources/STLerApp/Resources`. `cp` copies those attributes into the app bundle and `codesign` then fails with "resource fork, Finder information, or similar detritus not allowed". `Scripts/build.sh` copies with `cp -X` for that reason.
