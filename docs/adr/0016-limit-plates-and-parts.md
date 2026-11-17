# 0016. A per-type limit: how many plates or parts the icon shows

- Status: accepted
- Date: 2026-11-17

## Context

An icon is one small picture. A multi-plate Bambu/Orca 3MF drawn whole is a heap of overlapping parts, and a STEP assembly with hundreds of tiny parts shrinks the interesting ones to dust. `firstPlateOnly` was a global on/off switch and covered only the first case.

## Decision

`TypeStyle.limit` (0 = all), per file type, shown on the 3MF and STEP pages.
- 3MF: the first `limit` plates (`PlateParser` collects their object ids). Default 1, the old `firstPlateOnly=true`. Old configs migrate: the legacy flag maps to 1 or all.
- STEP: the first `limit` solids in file order, cut before meshing (FreeCAD: `Part.makeCompound`, OpenCASCADE helper: `--parts N`). The converter cache key includes the limit.
- The signature of 3MF and STEP includes the limit, prefix bumped to `v6`, so changing it re-renders only that type.

## Consequences

- File order is not size order: "first 25 parts" can be 25 screws. Picking the biggest parts by volume is a possible follow-up.
- A step that has no solids (surfaces only) is shown whole.
- One more mass re-render after the `v6` signature.
