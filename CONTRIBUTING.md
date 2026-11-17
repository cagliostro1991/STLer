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

## Pull requests, step by step

1. Fork the repository and make a branch in your fork (`fix/short-name`, `feat/short-name`).
2. `make test` passes before you start and before you push. CI runs the same on GitHub.
3. Change one thing. Bug fix: add a test that fails without it. New decision or macOS surprise: an ADR or a note in `docs/knowledge/` in the same PR.
4. Commit messages and the PR title in conventional style: `feat(follow): ...`, `fix(3mf): ...`, `docs: ...`. CI checks the title.
5. Open the pull request, fill in the template (what, why, how you checked). Link the issue with "Fixes #123".
6. CI has to be green, the maintainer reviews, you may be asked for changes. Pushing more commits to the branch updates the PR.
7. The PR is squashed into one commit on `main`, with your name as author.

- Say what you ran. "make test passes" is enough for small things. For anything that writes icons, mention that you tried it on a copy of some models, not your real folder.
- Using an AI assistant is fine. You still own the result: read the diff, run the tests, and delete anything you cannot explain.
- The settings window and the LaunchAgent are not covered by tests, so if you change them, say how you checked (a screenshot of the window, not of the whole screen).
- By contributing you agree that your contribution is licensed under the project's [MIT license](LICENSE). No sign-off or CLA is needed.
- Add yourself to `AUTHORS` in your first pull request if you like.

## Before you start

- **Small fix** (typo, obvious bug, doc improvement): just open a pull request.
- **Anything bigger** (a new setting, a new format, a change in how icons look): open an [issue](https://github.com/cagliostro1991/STLer/issues/new/choose) or start an [idea discussion](https://github.com/cagliostro1991/STLer/discussions/new?category=ideas) first, so nobody writes code that cannot be merged. A new format needs the "File format request" form, the traffic light in the README says how likely it is.
- Looking for a first task? See the issues labelled [good first issue](https://github.com/cagliostro1991/STLer/labels/good%20first%20issue) and [help wanted](https://github.com/cagliostro1991/STLer/labels/help%20wanted).

## What to expect from us

- A first reply within about a week. It is a spare-time project, a ping after two weeks is fine.
- Review comments are about the change, kindly meant. Disagreement is allowed, say why. See the [Code of Conduct](CODE_OF_CONDUCT.md).
- The maintainer decides in the end, and says why when the answer is no. A closed request is not a judgement about you.
- Every bug fix needs a test that fails without it (see AGENTS.md).

## Reporting a bug

Use the [bug report form](https://github.com/cagliostro1991/STLer/issues/new?template=bug_report.yml): it asks for the version, macOS version, what happened and what you expected. For wrong-looking icons attach the model (or a small one that shows the same problem) and the output of `stler config get`. Security problems go to [SECURITY.md](SECURITY.md), not to a public issue.

## Questions and ideas

[Discussions](https://github.com/cagliostro1991/STLer/discussions) is the place for "how do I", "what if" and "look what I made". If a discussion turns into concrete work, it becomes an issue.
