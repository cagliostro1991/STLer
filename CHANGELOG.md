# Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versions follow [semver](https://semver.org) with `-beta.N` for betas.

## Unreleased

## 0.1.0-beta.1

First public beta. See `docs/releases/v0.1.0-beta.1.md` for the full notes.

- Isometric (or other standard view, orthographic or perspective) icons for `.stl`, `.3mf` and `.step`/`.stp` files, set as Finder icons.
- Settings window in the style of System Settings: a page per file type (view, projection, colour, format label, plates or parts to show, model colours for 3MF), a General page (scope, `follow`, opening files, updates), a journal of jobs.
- `stler` CLI: `run`, `follow`, `reset`, `config`, `install`, `uninstall`, `version`, `update`.
- `stler follow` keeps icons up to date: the open Finder folder, new and changed files, files opened anywhere (optional).
- STEP through FreeCAD or OpenCASCADE (installed with Homebrew), one engine at a time.
- Update check against GitHub releases.
