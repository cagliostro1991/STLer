# 0013. Two STEP engines: FreeCAD or OpenCASCADE

- Status: accepted
- Date: 2026-11-17

## Context

STEP needs a CAD kernel. FreeCAD works but is about 2 GB for a thumbnail tool. OpenCASCADE is the kernel inside FreeCAD, about 45 MB to download and 160 MB on disk through Homebrew.

## Decision

`Config.stepEngine` is `freecad` or `opencascade`. Exactly one is used, and the STEP page shows a segmented switch with that engine's status and buttons. STEP stays off, and cannot be switched on, while the chosen engine is missing (`StepConverter.isReady`).

OpenCASCADE has no CLI, so a small C++ helper (`stler-step in out [in out ...]`) is compiled on first use with `clang++` from the Command Line Tools against the Homebrew keg, into `~/Library/Application Support/STLer`. The source is a string inside `OpenCascade.swift` and is recompiled when it changes. The Install button opens Terminal with `brew install opencascade` (via a `.command` file, so no Automation permission): the download is visible and can be stopped. Without Homebrew it opens brew.sh.

## Consequences

- Both engines share the cache and the one-run-per-batch rule.
- The helper links every `libTK*` the keg has and uses `-dead_strip_dylibs`, so it survives OCCT renaming its toolkits between versions.
- Compile failures come back as a `STEP skipped: ...` message instead of a crash.
