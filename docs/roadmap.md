# Roadmap

Last updated 2026-11-17.

## Needs the user
- Run `stler install`, confirm the Finder Automation prompt, check `~/Library/Logs/stler.log` (agent code is untested).
- Open the new settings window (sidebar layout, per-type pages, scope and confirmations) and check it feels right; I cannot see it.
- Re-render icons made before signature `v5` (iso camera roll bug, on-axis light, global settings): press Apply on a type page, or `stler --force <folder>`.

## Next
- Screenshots of the settings window for the README (needs a screenshot from the user), then make the repo public (the user's call).
- LaunchAgent: `install` should migrate or warn about an agent installed under an older name.

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
| OBJ, PLY | 🟢 Planned | ModelIO reads them, same path as STL |
| IGES/IGS | 🟢 Planned | same engines as STEP (FreeCAD or OpenCASCADE), another reader |
| AMF | 🟡 Maybe | open XML like 3MF, needs its own loader, little used |
| F3D (Fusion) | 🟡 Maybe | only the embedded `Previews/small.png` is readable (ADR 0009), so the icon would be Fusion's picture, not ours |
| USDZ, ABC | 🟡 Maybe | ModelIO reads them, rarely needed for printing |
| glTF, GLB, DAE | 🟡 Maybe | open formats, but ModelIO does not read them: own parser needed |
| FBX | 🔴 Unlikely | Autodesk format, the official SDK has a restrictive licence |
| SLDPRT, IPT, CATPART | 🔴 Unlikely | closed CAD formats, unreadable without the vendors' software |
