# 0011. Rename STyLer to STLer

- Status: accepted
- Date: 2026-11-17

## Context

"STyLer" is hard to find: several well-known projects are called styler (R, Elixir and XAML formatters). "STLer" is short, says what it is (STL plus "-er") and is unused.

## Decision

Rename everything at once while the repo is private: project, CLI (`stler`), app (`STLer.app`, bundle id `dev.pavlo.STLer`), source directories, environment variables (`STLER_CONFIG`, `STLER_TEST_OUT`), config path (`~/.config/stler/config.json`), cache and log paths, LaunchAgent label (`dev.stler.follow`) and the signature attribute (`dev.stler.sig`).

## Consequences

- Files iconed before the rename carry `dev.styler.sig`, which STLer ignores: they count as foreign, so `reset` skips them and the next `run`/`follow` re-renders them and stamps the new attribute. Remove the leftover attribute with `xattr -d dev.styler.sig <file>` if it matters.
- An old `~/.config/styler/config.json` is not read; copy it to `~/.config/stler/`.
- A LaunchAgent installed under the old name has to be removed with `launchctl bootout gui/$(id -u)/dev.styler.follow` and by deleting its plist.
