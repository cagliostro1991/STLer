# Release notes template

Copy this into a new file `docs/releases/vX.Y.Z[-beta.N].md`, fill it in, show it to the maintainer, publish only after approval.
Style: plain sentences, no emoji, no em-dashes, code in backticks, short.

---

## STLer X.Y.Z[-beta.N]

One or two sentences: what this release is about. For a beta, say what you want people to try.

### New
- ...

### Fixed
- ...

### Changed
- ...

### Known issues
- ...

### Install
1. Download `STLer-X.Y.Z-macos.zip`, unpack it.
2. Move `STLer.app` to Applications. The build is not notarized yet: the first time, right-click the app and choose Open, or run `xattr -dr com.apple.quarantine /Applications/STLer.app`.
3. Open the app, follow the welcome sheet to install `stler follow` (optional, it keeps icons up to date by itself).

Checksum (`shasum -a 256`): `...`

### Commits
Paste `git log --format='- %h %s' PREVIOUS_TAG..HEAD` here.

### Authors
Names of everyone with a commit in this range.

---

## Release steps
See [process.md](process.md#release): version bump PR, notes from this template, `Scripts/release.sh`, tag, pre-release on GitHub, check that the previous version sees the update.
