# Workflow recipes

## Add a setting
1. Property + doc comment in `Config`, a branch in `Config.set` with validation, tolerant decoding in `init(from:)`.
2. Does it change the picture? Add it to `Signature.make`; if the renderer output itself changed, bump the `v` prefix.
3. CLI: flag in `RunOptions` (if per-run) and the `usage` text. App: control in `SettingsView`.
4. Self-check: validation, fallback, signature effect. README config table.
5. ADR only if it is a real decision, not just a knob.

## Add a file format
1. Make the file readable as geometry (ModelIO, or a loader producing an `SCNNode`).
2. Add the extension to `Config.supportedFormats`, `FileScanner.collect`, the `IconRenderer.loadScene` switch, and the sample picker in `SettingsModel`.
3. Badge text defaults to the extension; override via `Options.badgeText` for aliases (`stp` shows `STEP`).
4. Test with a real file from a real tool, plus a tiny generated one in the self-check.
5. Write the format facts in `docs/knowledge/3mf-and-step.md` (or a new note) and an ADR if it brings a dependency.

## Change anything that writes icons
Go through `IconBatch`. Run `make test`, then the mutation check from `testing-safely.md`.

## Release / publish
1. `make test && make build` on a clean checkout.
2. README matches the code (config table, usage, limitations); roadmap updated.
3. The user approves the commit message (draft first), then commits; never push or change repo visibility without being asked.
4. Before going public: screenshots, `LICENSE` year/name, no personal paths (`git grep -n "/Users/"`).

## Planning
Working plans go to `plans/<slug>.md` (git-ignored) with the review pass: scope, risks, tradeoffs, decomposition, open questions. Durable outcomes move to `docs/` (ADR, knowledge, roadmap) and the plan is deleted.
