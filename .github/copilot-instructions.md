Read `AGENTS.md` in the repo root before changing anything: layout, code style, how to build and test, and what already went wrong.

The rules that must not be missed:

- Run `make test` before and after changes.
- Write icons only through `IconBatch` (it restores the file's modification date).
- Never test on real user files or the real `~/.config/stler/config.json`; use copies and `STLER_CONFIG`.
- Ask before pushing, publishing, or installing the LaunchAgent.
