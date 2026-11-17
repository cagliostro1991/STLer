# 0018. A bundled sample for every file type

- Status: accepted
- Date: 2026-11-17

## Context

The preview used the Benchy STL on every page, so the 3MF and STEP pages could not show what their own settings do (plates, model colours, part limit).

## Decision

Each type has a bundled sample next to `3DBenchy.stl`, made by a script in `Tools/`:
- `3DBenchy.3mf` (`Tools/make-benchy-3mf.swift`): the real Benchy three times as three objects on three plates with 1, 2 and 3 boats, painted by height, by length and by width with `basematerials`. About 6 MB.
- `3DBenchy.step` (`Tools/make-benchy-step.cpp`, OpenCASCADE): a Benchy-style tugboat built from separate solids (hull, deck, cabin with windows, roof, chimney, bollards). It is not a conversion of the mesh: a 225k-triangle mesh would be a 100+ MB STEP and would not split into closed solids. 240 KB.

The STEP preview goes through the chosen engine and the converter cache, so it respects the part limit; without an engine the page says so. "Choose sample..." is remembered per type in `UserDefaults`, a small "Benchy" button goes back to the bundled one.

## Consequences

- The repo grows by about 6.5 MB, the 3MF being the bulk. Reducing it means decimating the mesh, which changes the look.
- The STEP sample is a stand-in, not Benchy; the README says so.
- The generated files are committed; the tools are only needed to change them.
