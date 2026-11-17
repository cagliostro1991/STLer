# 3MF and STEP notes

## 3MF
- A package is a zip: `3D/3dmodel.model` (root), optional `3D/Objects/*.model`, `Metadata/*`.
- `transform` has 12 numbers: rows 1-3 of the 3x3 and the translation row; points are row vectors (`v' = v * M`). Compose component transform first, then the item/parent one.
- Production extension: `<component p:path="/3D/Objects/x.model" objectid="1">`; ids are per file.
- Bambu/Orca: `Metadata/model_settings.config` lists plates; each `<plate>` has `plater_id` and `<model_instance>` with `object_id`. Root `<build>` items cover all plates, so filter by the first plate's ids.
- Object `type` values `support`, `solidsupport`, `surface` are not part of the printed model.
- Slicer files also carry `Metadata/plate_N.png`; it shows the slicer's plate, not an isometric model view.
- Prusa/Fusion files are single-plate: no plate metadata, render every build item.

## STEP
- B-rep: needs a CAD kernel to tessellate. We use FreeCAD's `freecadcmd` with `Part.read` and `MeshPart.meshFromShape` (deflection about 0.1 % of the bounding diagonal), writing STL.
- Alternative engine: OpenCASCADE through a compiled helper, see ADR 0013. `Config.stepEngine` picks one.
- One engine run per batch; start-up dominates. Cache key = path + mtime + size (FNV-1a, not `hashValue`).
- `.stp` is the same format; treat both extensions as `step`.

## F3D
Zip with `Previews/small.png` and proprietary `OGS`/`Breps` blobs; not parseable, see ADR 0009.
