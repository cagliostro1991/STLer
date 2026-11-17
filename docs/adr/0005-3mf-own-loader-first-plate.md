# 0005. Own 3MF loader, first plate only

- Status: accepted
- Date: 2026-11-17

## Context

ModelIO reads STL but not 3MF. Real files come from Bambu/Orca/Prusa (objects in separate `.model` files via `p:path`, nested `components`, transform matrices) and Fusion (core spec). Bambu projects can hold many plates.

## Decision

Parse 3MF ourselves: `bsdtar` for archive access (`unzip` mangles non-ASCII member names), `XMLParser` for models, flatten everything into one world-space mesh with flat normals. For projects with plate metadata (`Metadata/model_settings.config`) render only the first plate (`firstPlateOnly`, default on). Skip `support`, `solidsupport`, `surface` objects.

## Consequences

- Depends on `/usr/bin/bsdtar` (ships with macOS).
- Units and materials are ignored (the render is normalised and single-coloured).
- Superseded in part by ADR 0016: the first-plate flag became a plate count (`3mf.limit`).
