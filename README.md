# STyLer

Isometric (or orthographic) icons for `.stl` and `.3mf` files in macOS Finder.

macOS ships its own Quick Look provider for STL and does not let third-party
thumbnail extensions override it (tested: a `QLThumbnailProvider` for
`public.standard-tesselated-geometry-format` is never called, even with a custom
UTI). STyLer renders each model offscreen with SceneKit and sets the result as the
file's custom icon via `NSWorkspace.setIcon`.

## Build

```
./build.sh
```

Produces `build/styler` (CLI) and `build/STyLer.app` (settings window). Needs only
the Command Line Tools; both are ad-hoc signed. `swift build` is not supported
(SwiftPM manifests do not link without full Xcode).

## CLI

```
styler [run] [--view V] [--color system|#RRGGBB] [--force|--no-force] [--depth N|deep]
       [--badge off|topLeft|topRight|bottomLeft|bottomRight] [--dry-run] [<folder|file>...]
styler follow
styler install | uninstall
styler reset [--all] [<folder|file>...]
styler config get [key] | set <key> <value>
```

- `run` without paths uses the folder open in Finder (fallback: cwd), then `watch` from the config.
- `follow` polls the front Finder window and renders each newly opened folder down to `followDepth`.
- `install` copies the binary to `~/.local/bin/styler` and registers a LaunchAgent that keeps `follow` running at login; `uninstall` removes the agent.
- Files already rendered with the same settings are skipped (signature in the `dev.styler.sig` xattr). `reset` removes only icons that carry that signature, never icons you set yourself.

## Config

`~/.config/styler/config.json`, written by the settings window and by `styler config set`.

| key | values | default |
| --- | --- | --- |
| `view` | `iso`, `front`, `back`, `left`, `right`, `top`, `bottom` | `iso` |
| `color` | `system` (system gray) or `#RRGGBB` | `system` |
| `formats` | list of `stl`, `3mf`, `step` (`step` needs FreeCAD) | `stl`, `3mf` |
| `firstPlateOnly` | bool, 3MF projects with several plates | `true` |
| `force` | bool, re-render even if up to date | `false` |
| `followDepth` | `1` (open folder only), `2`, `3`..., `0` = unlimited (`deep` in the CLI) | `3` |
| `freecadPath` | path to `freecadcmd`, empty = `/Applications/FreeCAD.app/...` | empty |
| `badge` | `off` or the corner of the format label | `bottomRight` |
| `watch` | folders used by `reset --all` | empty |

CLI flags override the config for one run.

## Formats

- STL (via ModelIO)
- STEP/STP (optional): converted to a cached STL with FreeCAD's headless `freecadcmd`, one FreeCAD run per batch; the cache lives in `~/Library/Caches/styler`. Off by default, skipped with a message when FreeCAD is missing.
- 3MF: core spec, `components` with transforms, production-extension `p:path`
  (Bambu Studio, Orca, Prusa, Fusion). Only the first plate of a Bambu/Orca
  project is rendered; `support` objects are skipped.

## Tests

```
./test.sh
```

Compiles the core with `Tests/main.swift` and runs about 30 checks: config validation,
folder depth, 3MF transforms and first-plate filtering, the signature, and an end-to-end
render/skip/reset run that also checks the file's modification date is preserved.
Use `STYLER_CONFIG=/some/file.json` to keep tests and experiments away from your real config.

## Limitations

- The icon is stored in the file's resource fork: it is lost on `cp` without
  `-X`, in zip archives and on some network volumes.
- `follow` and the settings window read the front Finder window through
  AppleScript, so macOS asks once for Automation access to Finder.
- Z-up is assumed.
- F3D (Fusion archives) is not supported: the geometry is stored in undocumented binary blobs.
- Needs `/usr/bin/bsdtar` (ships with macOS) to read 3MF.
- The settings window and the LaunchAgent are not covered by automated tests.
