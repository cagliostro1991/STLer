# 0014. Settings window logic is not covered by tests

- Status: open, needs refactoring
- Date: 2026-11-17

## Context

`make test` builds only `STLerCore`. State and decisions that live in `SettingsModel` and `SettingsView` (the app target) have no tests. This already cost us a bug: the "use home folder" dialog was opened before the count was ready and, since a presented SwiftUI dialog keeps the text it was opened with, it showed "Counting model files ..." forever. The fix (count first, then open the dialog, `SettingsModel.proposeHomeScope`) has no regression test.

## Decision

Accept this for now. The fix is small and was verified by hand and by timing the Spotlight count in isolation (`FileScanner.estimate` itself is tested). Rule from `AGENTS.md`: a bug needs a test, and where that is not possible an ADR like this one records why.

## Consequences

- Done 2026-11-18: the automatic Apply (debounce, the newer change drops the older run) moved to `ApplyScheduler` and `Config.typesToApply(after:)` in `STLerCore`, with checks in `Tests/SelfCheck`.
- Still open: move the request/confirm flow (scope change, count, pending action) out of `SettingsModel` into `STLerCore` as a plain type with a completion callback, then test the order "count finished, then confirmation offered".
- Until then, changes to `SettingsModel` need a manual look at the window.
