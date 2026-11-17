# 0008. One typed config file for CLI, app and agent

- Status: accepted
- Date: 2026-11-17

## Context

Settings must be editable from a window and from the shell, and picked up by a long-running `follow` without a restart.

## Decision

`Config` (typed: `ViewAngle`, `LabelCorner`, per-type `TypeStyle`, ...) is persisted as `~/.config/stler/config.json` (`STLER_CONFIG` overrides). The app saves on every change, `follow` reloads it per folder, CLI flags are applied to a copy for one run. Decoding is tolerant per key; validation lives in `Config.set`.

## Consequences

- One validation path for CLI and app; the enum raw values are the file format.
- Tests and experiments must point `STLER_CONFIG` at a temp file (a test run once deleted the real one).
