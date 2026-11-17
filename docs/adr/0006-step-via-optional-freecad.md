# 0006. STEP through optional FreeCAD

- Status: accepted
- Date: 2026-11-17

## Context

STEP is B-rep (NURBS), not a mesh. macOS has no tessellator and writing one is out of scope. FreeCAD is ~2 GB, too heavy to require or bundle; OpenCASCADE via brew is lighter but needs a C++ helper and toolchain.

## Decision

STEP is a config format (`step`, off by default). When enabled, `freecadcmd` (auto-detected in `/Applications`, or `freecadPath`) converts a whole batch in one run to STL in `~/Library/Caches/stler`, keyed by path, modification time and size; the normal pipeline renders that STL with a `STEP` badge. Without FreeCAD the files are skipped with a message.

## Consequences

- No new dependency for users who do not need STEP.
- First render of a big folder is slow (FreeCAD start-up plus meshing); later ones hit the cache.
- Revisit with an OpenCASCADE helper if FreeCAD proves too slow.
