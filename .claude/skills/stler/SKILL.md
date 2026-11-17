---
name: stler
description: Use when working on the STLer repo (macOS STL/3MF/STEP Finder icons): building, testing, adding a setting or format, debugging icons not showing, or touching icon-writing code. Covers the safe-testing rules and where decisions and gotchas are recorded.
---

# STLer project skill

Read `AGENTS.md` first (layout, conventions, traps, what to ask about), then only what the task needs:

| Task | Read |
| --- | --- |
| Why is it built this way | `docs/adr/` |
| Component map, data flow | `docs/architecture.md` |
| Something behaves oddly on macOS | `docs/knowledge/macos-gotchas.md` |
| Running tests or experiments | `docs/knowledge/testing-safely.md` |
| 3MF / STEP details | `docs/knowledge/3mf-and-step.md` |
| Step-by-step recipes (new setting, new format, release) | `docs/knowledge/workflow.md` |
| What is left to do | `docs/roadmap.md` |

## Loop

1. `make test` before and after changes; it must still fail if `preservingModDate` is disabled (mutation check in `workflow.md`).
2. `make build` when the CLI or app changes; the running app and any agent need a relaunch to pick it up.
3. Icons not visible in Finder: re-enter the folder first (Finder caches), then check `xattr -l <file>` for `ResourceFork` and `dev.stler.sig`.
4. New decision or surprise: add an ADR or a knowledge note in the same change, so it is not rediscovered.

## Do not

Touch real user files or config in tests, install the LaunchAgent, take full-screen screenshots, commit without showing the message. All of it is spelled out in `AGENTS.md`.
