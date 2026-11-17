# Working on STLer

Short guide for anyone changing this repo, person or coding assistant. It is one plain file for both, so nobody has to read two sets of rules.

## What this is

A small macOS tool that renders isometric icons for `.stl`, `.3mf` and `.step` files and sets them as Finder icons. Swift, no Xcode, no dependencies. If something looks odd, there is probably an ADR for it in `docs/adr/`.

## Get going

```
make build   # build/stler (CLI) and build/STLer.app (settings window)
make test    # about 80 checks, a few seconds
```

You only need the Command Line Tools. Tests use temp files and a temp config, they never touch your files.

## Where things live

- `Sources/STLerCore/` the actual logic: config, renderer, 3MF loader, STEP converter, file scanner, signature, `IconBatch`. No printing, no UI.
- `Sources/STLerCLI/` argument parsing and commands. The only place that prints.
- `Sources/STLerApp/` the SwiftUI settings window, built on the same `Config`.
- `Tests/SelfCheck/main.swift` the tests, a plain executable (no XCTest, that needs Xcode).
- `docs/` architecture, ADRs (why), knowledge notes (gotchas and recipes), roadmap (what is left).

Keep directory names apart by more than case. APFS does not care about case and two folders will silently merge.

## How we write code

- English everywhere: code, comments, UI strings, commit messages, docs. No comments in other languages. (Talking to the maintainer is a different thing, answer in whatever language they write in.)
- Small files, one main type per file, PascalCase file names.
- Types and non-trivial functions get a `///` doc comment: one line of what it does, `- Parameter` and `- Returns` only when it is not obvious.
- Inline comments only for the non-obvious why. If a comment repeats the code, delete it.
- Typed values over strings (`ViewAngle`, `Projection`, `LabelCorner`, `FileType`). Stateless services are `enum` namespaces.
- Core returns results (`BatchResult`), it does not print.
- Settings live per file type in `Config`. A setting that changes the picture goes into `Signature.make` (per type). If the renderer output itself changes, bump the version prefix there so old icons re-render.

## Things that already bit us

Details and fixes are in `docs/knowledge/macos-gotchas.md`. The short list:

- `NSWorkspace.setIcon` changes the file's modification date. All icon writes go through `IconBatch`, which puts the date back. Do not call `setIcon` anywhere else.
- Never test against real folders or the real `~/.config/stler/config.json`. Use copies and `STLER_CONFIG`. Never delete someone's config as cleanup.
- `@State` does not compile without Xcode. Keep UI state in the `ObservableObject`.
- `unzip` garbles non-ASCII names in archives. We use `bsdtar`.
- A full-screen screenshot shows whatever else is on the screen. Ask for a screenshot of the window instead.

## Changing things

- One thing per commit, conventional style: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Run `make test` before and after. If you touch the icon writing code, check that the mtime tests still fail when the date restore is disabled (recipe in `docs/knowledge/testing-safely.md`).
- A new decision gets an ADR (copy `docs/adr/0000-template.md`), a new gotcha gets a note in `docs/knowledge/`. Put them in the same change, so the next person does not find out the hard way.
- Recipes for a new setting, a new format and a release are in `docs/knowledge/workflow.md`.
- The maintainer reads commit messages before they go in, so propose the message first.

## Ask first

Anything that leaves the machine or sticks around: pushing, publishing, changing repo visibility, installing the LaunchAgent (`stler install`), killing processes you did not start. Everything else, just do it.

## Working notes

Scratch plans go to `plans/` (git-ignored). When a plan produces something worth keeping, move that into `docs/` and delete the plan.
