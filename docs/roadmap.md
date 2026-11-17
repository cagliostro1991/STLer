# Roadmap

Last updated 2026-11-17.

## Needs the user
- Run `stler install`, confirm the Finder Automation prompt, check `~/Library/Logs/stler.log` (agent code is untested).
- Look at a real Finder icon with the badge and the fixed iso angle.
- Re-render icons made before signature `v3` (they were rolled by an iso camera bug): `stler --force <folder>` or open the folder with `force` on.

## Next
- Icon style settings: background colour, corner radius, model opacity and background opacity (all in `Config` and the signature, composed after the render, controls in the settings window and `stler config`). Open question: whether "opacity" should also cover the background (planned as two separate sliders).
- Re-evaluate the front folder during a long run so switching windows re-prioritises the queue.
- Screenshots for the README, then make the repo public.
- Settings window: show progress for long batches.

- STL files with zero facet normals render flat gray (seen with a generated test model; real exports usually carry normals). Recompute normals through ModelIO when they are missing.

## Maybe
- Notarised app build (needs a paid Apple Developer account).
- OpenCASCADE helper as a lighter STEP backend than FreeCAD.
- F3D: only Fusion's embedded `Previews/small.png` is readable, see ADR 0009.
