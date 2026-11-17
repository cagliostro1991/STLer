# 0007. Preserve the modification date

- Status: accepted
- Date: 2026-11-17

## Context

`NSWorkspace.setIcon` updates the file's modification date (verified: 2020-01-01 became "now"). The first bulk run touched ~850 of the user's files before this was noticed; their original dates are unrecoverable (no Time Machine).

## Decision

Wrap every icon write and reset in `preservingModDate`, which restores the date afterwards. A self-check asserts it for both apply and reset, and was confirmed to fail when the restore is disabled.

## Consequences

- Finder "Date Modified" sorting and slicer file lists stay truthful.
- Never bypass `IconBatch` when writing icons.
- Lesson recorded in `docs/knowledge/testing-safely.md`: probe side effects on a copy before any bulk run on real data.
