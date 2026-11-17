# Testing safely

## Rules
1. Experiments run on copies in a scratch directory, never on the user's folders.
2. Point `STLER_CONFIG` at a temp file. `Scripts/test.sh` already does. Never `rm` the real `~/.config/stler/config.json`: the settings window writes it and it may hold values nobody remembers.
3. Probe side effects of an API on one throwaway file before a bulk run (the `setIcon` mtime bump was found only after ~850 files).
4. Do not install the LaunchAgent or kill the user's processes without being asked. `pkill -f "stler follow"` is fine for a process you started yourself.
5. GUI cannot be screenshotted by the agent; use `--dry-run`, the CLI and the self-check, then ask for a screenshot.

## Recipes
- Orientation is checked on pictures: the self-check builds dumbbell and pillar models from boxes, renders each rotation (+X, +Y, -X, -Y) and compares where the mass sits in the silhouette with what the camera geometry predicts. `STLER_TEST_OUT=/some/dir make test` also dumps the PNGs so you can look at them.
- Mutation check for the mtime guarantee: copy `Sources/STLerCore` to a temp dir, disable the `defer` in `preservingModDate`, build with `Tests/SelfCheck/main.swift`, expect two FAILs.
- Follow mode without touching real folders: copy models to a scratch folder, run `stler follow` with `STLER_CONFIG`, and move the front Finder window with `osascript -e 'tell application "Finder" to set target of front window to POSIX file "..."'`. The user's own clicks pollute the log; prefer `--dry-run` for ordering questions.
- STEP: tiny `.stp` files in the wild are code samples, not models; use a real file of at least tens of KB.
