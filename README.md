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
make test    # about 50 checks, no Xcode needed
```

Only the Command Line Tools are required; the app is ad-hoc signed. `swift build` is not supported (see `docs/adr/0004-swiftc-and-make-no-xcode.md`).

## CLI

```
stler [run] [--view V] [--color system|#RRGGBB] [--force|--no-force] [--depth N|deep]
       [--badge off|topLeft|topRight|bottomLeft|bottomRight] [--dry-run] [<folder|file>...]
stler follow
stler install | uninstall
stler reset [--all] [<folder|file>...]
stler config get [key] | set <key> <value>
```

- `run` without paths uses the folder open in Finder (fallback: cwd), then `watch` from the config.
- `follow` polls the front Finder window and renders each newly opened folder down to `followDepth`.
- `install` copies the binary to `~/.local/bin/stler` and registers a LaunchAgent that keeps `follow` running at login; `uninstall` removes the agent.
- Files already rendered with the same settings are skipped (signature in the `dev.stler.sig` xattr). `reset` removes only icons that carry that signature, never icons you set yourself.

## Config

`~/.config/stler/config.json`, written by the settings window and by `stler config set`.

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
- STEP/STP (optional): converted to a cached STL with FreeCAD's headless `freecadcmd`, one FreeCAD run per batch; the cache lives in `~/Library/Caches/stler`. Off by default, skipped with a message when FreeCAD is missing.
- 3MF: core spec, `components` with transforms, production-extension `p:path`
  (Bambu Studio, Orca, Prusa, Fusion). Only the first plate of a Bambu/Orca
  project is rendered; `support` objects are skipped.

## Tests

`make test` compiles the core with `Tests/SelfCheck/main.swift` and runs the checks on temp files: config validation, folder depth, 3MF transforms and first-plate filtering, signature, and an end-to-end render/skip/reset run that also asserts the file's modification date survives. `STLER_CONFIG=/some/file.json` keeps experiments away from your real config.

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
- Preview model: [3DBenchy](https://www.3dbenchy.com/) by Creative Tools.
