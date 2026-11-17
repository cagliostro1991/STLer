# 0003. Follow Finder by polling AppleScript

- Status: accepted
- Date: 2026-11-17

## Context

The intended behaviour is "I open a folder, its models get icons". Finder posts no public notification for navigation. FSEvents sees file changes, not which folder is open; `launchd` `WatchPaths` is not recursive.

## Decision

`stler follow` asks Finder for the front window's folder every 2 s (`NSAppleScript`, in-process, main thread) and processes it down to `followDepth`. A LaunchAgent keeps it running (`stler install`).

## Consequences

- Needs one-time Automation consent per binary (`NSAppleEventsUsageDescription` for the app).
- Rendering blocks the poll loop; a big first-time folder delays detection of the next one.
- Cheap and robust; a watcher for new files in `watch` folders remains an option.
