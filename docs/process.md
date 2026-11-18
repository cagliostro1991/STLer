# Process

How a change gets from an idea to a release. Agreed on 2026-11-18 so the format is not discussed again: if something here should be different, change this file in a pull request and it applies from then on. Written for the maintainer and for coding assistants; contributors can follow the short version in [CONTRIBUTING.md](../CONTRIBUTING.md).

## At a glance

1. Branch from `origin/main`, one topic per branch.
2. Change, then `make format`, `make check`, `make test`, `make build`.
3. Draft the commit messages, the maintainer approves them, commit.
4. Push the branch, draft the PR title and body, the maintainer approves them, open the PR.
5. CI green (`build-and-test`, `pr-title`), merge, delete the branch, update `main`.
6. A release adds a version bump PR, notes, an archive, a tag and a GitHub release.

`main` is protected: pull request only, both checks required, no force push, no deletion. Nothing is committed to `main` directly.

## Who approves what

| Step | Needs the maintainer's yes | Then, without asking again |
|---|---|---|
| Commit | the message draft (one approval covers one commit) | commit exactly that |
| Pull request | the title and the body | push the branch, open it, merge once CI is green, delete the branch |
| Release | the notes text and the commit message of the bump | merge the bump, tag, publish, check the update check sees it |
| Wiki sync | the commit message | push |
| Repository settings, visibility, secrets, deleting someone else's branches or tags | always, case by case | |

Approval is for the content. The format is fixed below, so a draft that follows it can be answered with one word. A coding assistant shows each draft in the chat, in the maintainer's language for the discussion and in English for the text itself, and never publishes text that was not shown.

## Branches

- Names: `feat/…`, `fix/…`, `refactor/…`, `docs/…`, `chore/…` (same types as commits), short and lowercase.
- Always from a fresh `origin/main`. The main checkout stays on `main`.
- Parallel topics: use `git worktree add <dir> -b <branch> origin/main` instead of switching branches with uncommitted work. Remove the worktree when the PR is merged.
- After the merge the branch is deleted locally and on GitHub.

## Before every commit

```
make format   # swift-format, config in .swift-format (100 columns, 4 spaces)
make check    # type-check of the three builds, format lint, whitespace
make test     # self-check, about 20 seconds
make build    # needed when the app, the build script or resources changed
```

- Every bug fix comes with a test that fails without it, or an ADR that says why it cannot be tested ([AGENTS.md](../AGENTS.md)).
- Formatting the whole tree is its own commit and never mixed with behaviour.
- `make editor` once per clone writes `compile_commands.json` so the editor understands the project.
- Git identity per clone: the GitHub no-reply address ([workflow.md](knowledge/workflow.md)). Also in the wiki clone.

## Commit messages

- Conventional: `type(scope): description`, types `feat`, `fix`, `refactor`, `docs`, `test`, `style`, `chore`, `ci`, `perf`. Scope is optional and short (`app`, `site`, `build`, `cli`).
- English, imperative or plain description, lowercase after the colon, no full stop, up to about 90 characters.
- One logical change per commit. The reason goes in the body only when it is not obvious.
- No emoji, no em-dashes, no AI attribution or co-author lines.

## Pull requests

- Title: a conventional commit title (CI checks it). For a multi-commit PR, the title says what the whole change is.
- Body: plain short sentences and `-` bullets, no headings unless it is long. Say what changed and why, what was not checked, and that `make check`, `make test` and `make build` pass. Mention anything the reviewer must do after the merge (for example `make editor`).
- Link the issue with "Fixes #N" when there is one.
- The body is written like the maintainer writes: casual and short, code-ish words in backticks. Example:

```
Moves the logic behind the automatic Apply out of SettingsModel into STLerCore, where self-check can reach it.

- ApplyScheduler: waits for a quiet moment, a newer change of the same type drops the older run
- 10 new checks; ADR 0014 updated

make check, make test and make build pass.
```

## Merging

- Wait for `build-and-test` and `pr-title`: `gh pr checks N --watch`.
- Several commits that each stand alone (a style commit, then a change): rebase merge, `gh pr merge N --rebase`.
- One commit, or a bot PR (Dependabot): squash, `gh pr merge N --squash`.
- Then `git checkout main && git pull --ff-only`, delete the branch locally and with `git push origin --delete <branch>`.
- Dependabot PRs: read the diff (usually one version number), merge when CI is green. Changes to `pages.yml` deploy the site after the merge, so look at the Pages run.

## Release

Beta numbering is `0.1.0-beta.N`, tags are `v` plus the version. Steps in order:

1. Branch `chore/release-<version>`. Bump `VERSION` and `AppVersion.current` (a self-check keeps them equal), move "Unreleased" in `CHANGELOG.md` under the new version with the date, bring `docs/roadmap.md` up to date.
2. Notes in `docs/releases/v<version>.md` from [release-template.md](release-template.md): what the release is about, New, Changed, Fixed, Known issues, Install, checksum, commits since the last tag, authors. Plain sentences, no emoji, no em-dashes.
3. `Scripts/release.sh` builds `dist/STLer-<version>-macos.zip` and its `.sha256`. Unzip it somewhere else and check: `codesign -v`, the version in `Info.plist` and in `stler version`, no stray attributes. Put the checksum in the notes.
4. Commit `chore(release): <version>`, PR with the same title, merge on green CI.
5. On the merged commit: `git tag v<version> && git push origin v<version>`, then `gh release create v<version> --prerelease --title "STLer <version>" --notes-file docs/releases/v<version>.md dist/*.zip dist/*.sha256` (a beta is always a pre-release).
6. Check that the previous version's `stler update` reports the new one (the app reads the GitHub releases).

## Site and wiki

- `site/` is published by GitHub Pages when a change under `site/` reaches `main`. Pictures come from `Scripts/site-images.sh` (needs ImageMagick and cwebp; the full-size screenshots live in `icons/` and are not committed). Look at the page in a browser before the PR: wide, narrow, dark and light.
- The wiki is generated from `docs/wiki/`. Sync after the PR is merged: clone `git@github.com:cagliostro1991/STLer.wiki.git`, set the no-reply identity, copy the files without `README.md`, commit `Sync from docs/wiki`, push.

## Where the rest lives

- Layout, code style, traps: [AGENTS.md](../AGENTS.md). Recipes (a setting, a file type): [knowledge/workflow.md](knowledge/workflow.md).
- Why things are the way they are: `docs/adr/`. macOS surprises: `docs/knowledge/macos-gotchas.md`. What is next: [roadmap.md](roadmap.md).
