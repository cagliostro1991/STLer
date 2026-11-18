# Roadmap

Last updated 2026-11-18.

## Needs the user
- Check that the icons look right in your own Finder folders after an update, and report what does not (the format request and bug forms are linked from the app, About).

## Next
- OBJ and PLY icons (built on a branch, off by default, drawn Z up like STL), then an up-axis option per type for Y-up files.
- IGES/IGS with the same engines as STEP.
- Test the request/confirm flow of the settings window (ADR 0014 is still open for it).

## Maybe
- Notarised app build (needs a paid Apple Developer account).
- Try OpenCASCADE on more STEP files (assemblies, huge models); verified so far on one real assembly.
- Model colours for STEP (needs a colour-aware reader and a coloured mesh format), and Bambu per-triangle paint for 3MF (ADR 0017).
- Pick the biggest STEP parts instead of the first ones (ADR 0016).

## Formats
Traffic light: 🟢 done or planned, 🟡 maybe, 🔴 unlikely (closed format or licence). The same table is on the site.

| Format | Light | Notes |
|---|---|---|
| STL, 3MF, STEP/STP | 🟢 Done | |
| OBJ, PLY | 🟢 Done (off by default) | ModelIO reads them, same path as STL; Z up, an up-axis option is not built yet |
| IGES/IGS | 🟢 Planned | same engines as STEP (FreeCAD or OpenCASCADE), another reader |
| AMF | 🟡 Maybe | open XML like 3MF, needs its own loader, little used |
| F3D (Fusion) | 🟡 Maybe | only the embedded `Previews/small.png` is readable (ADR 0009), so the icon would be Fusion's picture, not ours |
| USDZ, ABC | 🟡 Maybe | ModelIO reads them, rarely needed for printing |
| glTF, GLB, DAE | 🟡 Maybe | open formats, but ModelIO does not read them: own parser needed |
| FBX | 🔴 Unlikely | Autodesk format, the official SDK has a restrictive licence |
| SLDPRT, IPT, CATPART | 🔴 Unlikely | closed CAD formats, unreadable without the vendors' software |
