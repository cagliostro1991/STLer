# 0017. Model colours: a slider between the fill colour and the colours in the file

- Status: accepted (3MF only, STEP open)
- Date: 2026-11-17

## Context

3MF files often carry colours, and a single fill colour throws them away. Some people want the file's colours, some want one uniform look.

## Decision

`TypeStyle.modelColors` is 0...100. At 0 the whole model has the fill colour (the old look, nothing is read from the file). Above 0 each part gets `fill + (file colour - fill) * amount`; parts with no colour keep the fill. Colours are baked into per-corner vertex colours (`FlatGeometry`) and the material is white, so the picture is lit as before.

Sources, strongest first: the triangle's own `pid/p1`, the object's `pid/pindex` (core `basematerials`, materials-extension `colorgroup`), then for Bambu/Orca the object's filament (`extruder` in `model_settings.config` looked up in `filament_colour` of `project_settings.config`). Part-level extruders and per-triangle paint (`paint_color`) are not read. Signature of 3MF and STEP includes the value.

## Consequences

- The default is 0, so nothing changes for existing icons until the slider moves.
- The preview shows the effect only with a coloured sample (Choose sample...); the bundled Benchy is an STL.
- STEP colours are not done: `stler-step` writes STL, which has no colours. It needs a colour-aware reader (XDE `STEPCAFControl`) and a format with colours (PLY or OBJ) for both engines.
