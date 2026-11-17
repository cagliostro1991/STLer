# Architecture

```
            +----------------+       +----------------+
 Finder --> | FinderFolder   |       |  config.json   | <-- STLer.app (settings window)
 (front     | (AppleScript)  |       |  (Config)      | <-- stler config set
  window)   +-------+--------+       +-------+--------+
                    |                        |
                    v                        v
 stler follow --> IconBatch.applyToFolder --+--> FileScanner (depth, order, formats)
 stler run    --> IconBatch.apply
                    |
        +-----------+-------------+
        v                         v
 Signature (xattr)          IconRenderer (SceneKit, offscreen)
 skip unchanged             |-- ModelIO          .stl
                            |-- ThreeMFLoader    .3mf   (bsdtar + XMLParser)
                            '-- StepConverter    .step  (optional FreeCAD, cached STL)
                    |
                    v
        NSWorkspace.setIcon  (+ modification date restored)
```

## Components

| Unit | Responsibility |
| --- | --- |
| `Config`, `TypeStyle`, `LabelStyle` | Settings model per file type, validation (`set` with dotted keys), JSON persistence, tolerant decoding, migration of old files |
| `FileType` | `stl`, `3mf`, `step`: extensions, title, lookup by path |
| `ViewAngle`, `Projection`, `LabelCorner` | Typed camera presets, projection and label corners |
| `FileScanner` | Recursive search with depth limit, top-level-first ordering, dedupe |
| `FinderFolder` | Front Finder window via AppleScript (main thread only) |
| `IconRenderer` | Model file to `NSImage`: material, orthographic or perspective camera, side light, then the format label (colours, radius, opacity) |
| `FlatGeometry` | Triangle soup with one normal per triangle; shared by the STL and 3MF paths |
| `ThreeMFLoader` | 3MF package to one SceneKit node (components, transforms, `p:path`, first plate) |
| `StepConverter` | STEP to cached STL through the chosen engine (`freecadcmd` or the OpenCASCADE helper) |
| `JobQueue` | one-at-a-time background jobs with progress; the window's Apply and Clear are jobs |
| `ActivityLog` | JSON log shared by `stler follow` and the window, last 10 finished entries |
| `OpenCascade` | Homebrew lookup, Install via Terminal, compiles the `stler-step` helper |
| `Signature` | `dev.stler.sig` xattr: which settings of the file's type produced the current icon |
| `IconBatch` | Apply / reset icons; the only place that writes icons |
| `stler` CLI | Flag parsing and commands; the only place that prints |
| `STLerApp` | SwiftUI window in System Settings style (sidebar: General, one page per type) over the same `Config`; Clear and Apply use `IconBatch`, with confirmation and file counts |

## Data flow of one folder

1. `follow` sees a new front folder (poll every 2 s) or the user runs `run`/presses Apply.
2. `FileScanner.scan` returns files in enabled formats, top level first, down to `followDepth`.
3. `IconBatch.apply` computes the signature from `Config`, skips files that already carry it (unless `force`), converts STEP files in one FreeCAD run, renders each file, writes the icon and the signature, restores the modification date.
4. `reset` removes icons only from files carrying a signature.

## Boundaries

- Core never prints and never touches UI; callers format `BatchResult`.
- All settings flow through `Config`; CLI flags are applied to a copy for one run.
- The app and the CLI share Core source files (compiled together; there are no module boundaries).
