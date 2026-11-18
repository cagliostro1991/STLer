# Workflow recipes

## Add a setting
1. Per-type setting: property + doc comment in `TypeStyle` (or `LabelStyle`), a branch in its `set` with validation, tolerant decoding in its `init(from:)`. Global setting: same in `Config`.
2. Does it change the picture? Add it to `Signature.make` (per type); if the renderer output itself changed, bump the `v` prefix.
3. CLI: dotted key works automatically through `Config.set`; add a flag in `RunOptions` only if it is useful per run, and update `usage`.
4. App: a control on the type page in `SettingsView` (bindings go through `style`/`label` helpers).
5. Self-check: validation, fallback, signature effect, and a pixel check if it changes the picture. README config table.
6. ADR only if it is a real decision, not just a knob.

## Add a file type
1. Make the file readable as geometry (ModelIO, or a loader producing an `SCNNode`).
2. `FileType` case (extensions, title), a `TypeStyle` field in `Config` with its `subscript` branch and `CodingKeys` entry, `IconRenderer.loadScene`, the sample picker in `SettingsModel`, an icon and tint in `SettingsView`.
3. Label text is the type title; the old `step` style conversion path (`StepConverter`) is the pattern for formats that need a converter.
4. Test with a real file from a real tool, plus a tiny generated one in the self-check.
5. Write the format facts in `docs/knowledge/3mf-and-step.md` (or a new note) and an ADR if it brings a dependency.

## Change anything that writes icons
Go through `IconBatch`. Run `make test`, then the mutation check from `testing-safely.md`.

## Git identity (do this in every new clone)
Commit history is public, and so is the e-mail in it. This repository uses the GitHub no-reply address, set per repository (not globally):
```
git config user.name "Pavlo Zubenko"
git config user.email "cagliostro1991@users.noreply.github.com"
git log --format='%ae' | sort -u     # must print only the no-reply address
```

## Release / publish
The steps, the approvals and the formats are in [process.md](../process.md#release). Two facts that are easy to forget: the version lives in two places that a self-check keeps equal (`VERSION` and `AppVersion.current` in `Sources/STLerCore/Version.swift`), and the in-app update check reads GitHub releases, so a version that is not released there is never offered. `Scripts/release.sh` builds the archive. Before going public with anything new: screenshots, no personal paths (`git grep -n "/Users/"`).

## Planning
Working plans go to `plans/<slug>.md` (git-ignored) with the review pass: scope, risks, tradeoffs, decomposition, open questions. Durable outcomes move to `docs/` (ADR, knowledge, roadmap) and the plan is deleted.
