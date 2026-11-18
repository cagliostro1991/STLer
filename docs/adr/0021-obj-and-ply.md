# 0021. OBJ and PLY: opt-in types, Z up, generated samples

- Status: accepted
- Date: 2026-11-18

## Context

ModelIO reads OBJ and PLY, so they go down the same path as STL (`IconRenderer.loadScene`, `FlatGeometry`). Three questions came up.

## Decision

- **Off by default.** OBJ and PLY are used well outside 3D printing (assets, scans). With `follow` running, turning them on for everybody would put icons on files in the user's Finder folders that they never asked about. A type is switched on on its own page.
- **Z up, like STL.** OBJ and PLY carry no up-axis information. Files from slicers and CAD are Z up, files from Blender are often Y up and will lie on their side. The view picker can rotate them for now. An up-axis option per type is the follow-up if people ask (roadmap).
- **No shipped samples.** The preview needs a Benchy of the type, but exporting the STL gives an 18 MB file for each. `SampleFiles` exports them with ModelIO once into `~/Library/Caches/stler/samples`, in the background when the app starts, and the preview appears when it is ready.

## Consequences

- The signature of an OBJ or PLY icon has no plate or colour part (like STL). Existing configs keep working: missing keys fall back to the defaults.
- A Y-up OBJ looks wrong until the up-axis option exists.
