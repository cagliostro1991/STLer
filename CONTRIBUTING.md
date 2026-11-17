# Contributing

Thanks for looking. The short version:

1. `make test` should pass before you start and before you open a PR.
2. Keep the change small and about one thing.
3. If you made a decision or hit a macOS surprise, write it down in `docs/adr/` or `docs/knowledge/` in the same PR.

Everything about the layout, code style and the traps we already fell into is in [AGENTS.md](AGENTS.md). It is written for people and coding assistants alike, so it is the only place to read.

## Setup

```
make build
make test
```

Only the Command Line Tools are needed, no Xcode.

## Pull requests

- Conventional commit messages (`feat: ...`, `fix: ...`, `docs: ...`).
- Say what you ran. "make test passes" is enough for small things. For anything that writes icons, mention that you tried it on a copy of some models, not your real folder.
- Using an AI assistant is fine. You still own the result: read the diff, run the tests, and delete anything you cannot explain.
- The settings window and the LaunchAgent are not covered by tests, so if you change them, say how you checked.

## Reporting a bug

Include macOS version, the command or window action, what you expected, what happened. For wrong-looking icons attach the model (or a small one that shows the same problem) and the output of `stler config get`.
