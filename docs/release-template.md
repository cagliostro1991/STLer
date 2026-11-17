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
1. `make test` is green, `VERSION` and `AppVersion.current` in `Sources/STLerCore/Version.swift` are the new version.
2. Move the entries of `CHANGELOG.md` "Unreleased" under the new version.
3. `Scripts/release.sh`, check the archive opens on a clean account if you can.
4. Commit (message approved first), tag `vX.Y.Z[-beta.N]`.
5. Push the commit and the tag, create the GitHub release from the notes file. Mark betas as pre-release (`gh release create TAG --prerelease --notes-file FILE dist/*.zip dist/*.sha256`).
6. The update check in the app reads these releases, so a beta shows up for beta users only after step 5.
