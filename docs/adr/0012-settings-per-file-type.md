# 0012. Settings per file type, label with its own style

- Status: accepted
- Date: 2026-11-17

## Context

One global look (view, colour, badge, formats list) is too coarse: STL, 3MF and STEP files are different things and people want them to look different (and to switch each on or off). The format label also needs its own colours, rounding and opacity. A first attempt at a tile style (background, corner radius, model opacity) was dropped: what was wanted were label settings.

## Decision

`Config` has one `TypeStyle` per file type (`stl`, `3mf`, `step`: `enabled`, `view`, `projection`, `color`, `label`) and `LabelStyle` (`corner`, `textColor`, `backgroundColor`, `cornerRadius`, `opacity`). Fixed fields rather than a dictionary, so the JSON stays an object (Swift encodes enum-keyed dictionaries as arrays). `Projection` (`orthographic`, `perspective`) joins the standard `ViewAngle` presets. The signature is per type, so changing one type never re-renders another.

The window mirrors this: a System Settings style sidebar with a page per type, and a General page with the scope (a chosen folder or the home folder) and the follow depth. Each type page has Clear and Apply; Clear always confirms, Apply confirms for the home folder, both show the file count first. Apply renders only stale files, which covers every setting because the signature includes them. Removed: global `view/color/formats/badge`, `force` (CLI `--force` stays), `watch` (the scope replaces it).

Older config files are migrated on read: the global view, colour and badge are copied to every type and `formats` becomes the enabled flags.

## Consequences

- Dotted CLI keys (`stl.view`, `3mf.enabled`, `step.label.textColor`); CLI view flags change every enabled type for one run.
- A new file type means a `FileType` case, a `Config` field and a subscript branch.
- One more mass re-render after the signature moved to `v5`.
- The home-folder scope is powerful: the confirmation dialog is part of the feature, not decoration.
