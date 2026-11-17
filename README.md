# STLer

Isometric (or orthographic) icons for `.stl`, `.3mf` and `.step` files in macOS Finder.

![STLer preview: isometric, coloured and front view](docs/preview.png)

macOS ships its own Quick Look provider for STL and does not let third-party
thumbnail extensions override it (tested: a `QLThumbnailProvider` for
`public.standard-tesselated-geometry-format` is never called, even with a custom
UTI). STLer renders each model offscreen with SceneKit and sets the result as the
file's custom icon via `NSWorkspace.setIcon`.

## Build

```
make build   # build/stler and build/STLer.app
make test    # about 80 checks, no Xcode needed
```

Only the Command Line Tools are required; the app is ad-hoc signed. `swift build` is not supported (see `docs/adr/0004-swiftc-and-make-no-xcode.md`).

## Settings window

`STLer.app` looks like System Settings: a sidebar with General, STL, 3MF and STEP (each type's tile has the type's colour and turns gray when the type is off). Each file type page has its own switch, view (isometric, front, back, left, right, top, bottom), projection (orthographic or perspective), colour and format label (position, text colour, background colour, corner radius, opacity), plus Clear and Apply buttons. General holds the scope the buttons work on (any number of chosen folders, or your home folder with a confirmation that shows the file count) and how deep `follow` goes. The preview on every page is 3DBenchy rendered with that page's settings.

## CLI

```
stler [run] [--view V] [--projection orthographic|perspective] [--color system|#RRGGBB]
      [--label off|topLeft|topRight|bottomLeft|bottomRight] [--depth N|deep] [--force] [--dry-run] [<folder|file>...]
stler follow
stler install | uninstall
stler reset <folder|file>...
stler config get [key] | set <key> <value>
```

- `run` without paths uses the folder open in Finder (fallback: cwd). View flags change every enabled type for that run only.
- `follow` polls the front Finder window and renders each newly opened folder down to `followDepth`; a long run gives way when you open another folder.
- `install` copies the binary to `~/.local/bin/stler` and registers a LaunchAgent that keeps `follow` running at login; `uninstall` removes the agent.
- Files already rendered with the same settings are skipped (signature in the `dev.stler.sig` xattr, one per type). `reset` removes only icons that carry that signature, never icons you set yourself.

## Config

`~/.config/stler/config.json`, written by the settings window and by `stler config set`. Settings are per file type; older files with global `view`, `color`, `formats` and `badge` keys are migrated when read.

| key | values | default |
| --- | --- | --- |
| `<type>.enabled` | `stl`, `3mf`, `step` switch (`step` needs FreeCAD) | stl, 3mf on; step off |
| `<type>.view` | `iso`, `front`, `back`, `left`, `right`, `top`, `bottom` | `iso` |
| `<type>.projection` | `orthographic`, `perspective` | `orthographic` |
| `<type>.color` | `system` (system gray) or `#RRGGBB` | per type: STL `#4f8ff7`, 3MF `#f59e42`, STEP `#a66cf0` |
| `<type>.label.corner` | `off` or the corner of the format label | `bottomRight` |
| `<type>.label.textColor` | `#RRGGBB` | `#ffffff` |
| `<type>.label.backgroundColor` | `#RRGGBB` | `#262626` |
| `<type>.label.cornerRadius` | 0 to 50, percent of the label height (50 = pill) | `50` |
| `<type>.label.opacity` | 0 to 1, background and text together | `0.85` |
| `firstPlateOnly` | bool, 3MF projects with several plates | `true` |
| `followDepth` | `1` (open folder only), `2`, `3`..., `0` = unlimited (`deep` in the CLI) | `3` |
| `freecadPath` | path to `freecadcmd`; empty = look in the usual places (`/Applications`, `~/Applications`, Homebrew) | empty |
| `scope`, `scopeFolders` | where the window's Clear and Apply work: `folder` with a list of folders (any number), or `home` | `folder`, empty list |

## Formats

- STL (via ModelIO)
- STEP/STP (optional): converted to a cached STL with FreeCAD's headless `freecadcmd`, one FreeCAD run per batch; the cache lives in `~/Library/Caches/stler`. Off by default and impossible to switch on while FreeCAD cannot be found: the STEP page of the settings window searches for it (usual places, then Spotlight), lets you choose it by hand, and keeps the type off without it.
- 3MF: core spec, `components` with transforms, production-extension `p:path`
  (Bambu Studio, Orca, Prusa, Fusion). Only the first plate of a Bambu/Orca
  project is rendered; `support` objects are skipped.

## Tests

`make test` compiles the core with `Tests/SelfCheck/main.swift` and runs the checks on temp files: config validation and migration, folder depth, 3MF transforms and first-plate filtering, per-type signatures, orientation, label and projection checked on rendered pixels, and an end-to-end render/skip/reset run that also asserts the file's modification date survives. `STLER_CONFIG=/some/file.json` keeps experiments away from your real config.

## Documentation

- `docs/architecture.md`: components and data flow
- `docs/adr/`: why things are the way they are
- `docs/knowledge/`: gotchas, safe testing, format notes, recipes
- `docs/roadmap.md`: what is left
- `AGENTS.md`: how to work on the repo, for people and coding assistants (`CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` and `.cursor/rules` just point to it)
- `CONTRIBUTING.md`: PR basics

## Limitations

- The icon is stored in the file's resource fork: it is lost on `cp` without
  `-X`, in zip archives and on some network volumes.
- `follow` and the settings window read the front Finder window through
  AppleScript, so macOS asks once for Automation access to Finder.
- Z-up is assumed.
- F3D (Fusion archives) is not supported: the geometry is stored in undocumented binary blobs.
- Needs `/usr/bin/bsdtar` (ships with macOS) to read 3MF.
- The settings window and the LaunchAgent are not covered by automated tests.

## Credits

- App icon artwork (`icons/`) was generated with Gemini.
- 3DBenchy by Creative Tools ([public domain](https://www.3dbenchy.com/license/)) is the preview model in the README and the default sample in the settings window (`Sources/STLerApp/Resources/3DBenchy.stl`, unmodified).
