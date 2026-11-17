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

## Release / publish
A full recipe with a notes template is in `docs/release-template.md`; `Scripts/release.sh` builds the archive.

1. `make test && make build` on a clean checkout.
2. README matches the code (config table, usage, limitations); roadmap updated.
3. The user approves the commit message (draft first), then commits; never push or change repo visibility without being asked.
4. Before going public: screenshots, `LICENSE` year/name, no personal paths (`git grep -n "/Users/"`).

## Planning
Working plans go to `plans/<slug>.md` (git-ignored) with the review pass: scope, risks, tradeoffs, decomposition, open questions. Durable outcomes move to `docs/` (ADR, knowledge, roadmap) and the plan is deleted.
