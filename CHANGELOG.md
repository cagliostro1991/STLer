# Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versions follow [semver](https://semver.org) with `-beta.N` for betas.

## Unreleased

## 0.1.0-beta.2 (2026-11-18)

- Accessibility: icon-only buttons have labels, status text keeps its contrast (only the symbol is coloured), "Off" is written in the sidebar instead of shown by colour alone, sliders show their value, Reduce Motion is respected.
- Menu bar: Check for Updates, an Icons menu (Regenerate, Clear, Show Journal with shortcuts) and a Help menu.
- The `stler follow` helper is called "background helper" in the window; long explanations moved into info popovers; shorter welcome sheet; US spelling "color".
- Changed settings apply on their own (a second after the last change). A newer change of the same type cancels the older job and starts over; adding a folder starts rendering it at once. The Apply button and the floating panel are gone; **Regenerate** forces every icon to be drawn again, **Clear** still asks first.
- Fixed: an empty row in the STEP engine section when OpenCASCADE is installed.

## 0.1.0-beta.1

First public beta. See `docs/releases/v0.1.0-beta.1.md` for the full notes.

- Isometric (or other standard view, orthographic or perspective) icons for `.stl`, `.3mf` and `.step`/`.stp` files, set as Finder icons.
- Settings window in the style of System Settings: a page per file type (view, projection, colour, format label, plates or parts to show, model colours for 3MF), a General page (scope, `follow`, opening files, updates), a journal of jobs.
- `stler` CLI: `run`, `follow`, `reset`, `config`, `install`, `uninstall`, `version`, `update`.
- `stler follow` keeps icons up to date: the open Finder folder, new and changed files, files opened anywhere (optional).
- STEP through FreeCAD or OpenCASCADE (installed with Homebrew), one engine at a time.
- Update check against GitHub releases.
