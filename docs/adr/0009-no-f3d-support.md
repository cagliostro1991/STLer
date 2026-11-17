# 0009. No F3D support

- Status: accepted
- Date: 2026-11-17

## Context

`.f3d` (Fusion archive) is a zip whose geometry sits in undocumented binary blobs (`OGS`, `Breps`). The only open part is `Previews/small.png` (Fusion's own 13 KB thumbnail). Fusion itself could export, but it is a live app, not a batch converter.

## Decision

Not supported. Possible fallback later: show the embedded preview with an `F3D` badge (different look from the other formats).

## Consequences

- Fusion users export STEP/3MF/STL first.
