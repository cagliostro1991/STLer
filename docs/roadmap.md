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
- OpenCASCADE helper as a lighter STEP backend than FreeCAD.
- F3D: only Fusion's embedded `Previews/small.png` is readable, see ADR 0009.
