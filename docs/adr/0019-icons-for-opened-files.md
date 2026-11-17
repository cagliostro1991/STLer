# 0019. Icons for files that are opened, anywhere

- Status: accepted
- Date: 2026-11-17

## Context

`stler follow` only reacted to the folder in front in Finder. A file opened from a flash drive in a slicer, with no Finder window on that drive, never got an icon.

## Decision

`OpenedFileWatcher` runs a live Spotlight query on `kMDItemLastUsedDate` (updated when a file is opened) over the indexed local scope, which includes connected drives. macOS has no "file opened" hook, this is the closest thing. Opened files get their icon first. With `followOpenedFolder` the other models directly in the same folder follow, from one directory listing (no subfolders, at most `FileScanner.siblingLimit` = 50, small files first), so one open never starts a long job. Both options are off by default and sit in a "When I open a file" section of General. Files in hidden folders and `Library` are ignored, as everywhere.

## Consequences

- Drives that Spotlight does not index are not seen.
- Nothing is rendered for files that already have the right icon, and such opens are not written to the journal.
- `follow` has to be running; General warns when it is not.
