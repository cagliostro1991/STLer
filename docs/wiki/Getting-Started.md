# Getting started

## Install

1. Download `STLer-<version>-macos.zip` from [Releases](https://github.com/cagliostro1991/STLer/releases) (betas are marked Pre-release) and unpack it.
2. Move `STLer.app` to Applications.
3. The build is not notarized yet. The first time, right-click the app and choose **Open**, or run in Terminal:
   ```
   xattr -dr com.apple.quarantine /Applications/STLer.app
   ```
4. Open the app. A welcome sheet explains what it does and why there is a command line tool. The question mark in the header shows it again.

## First icons

1. Open **General** and choose where icons are set: a folder (or several) or your home folder.
2. Pick a file type in the sidebar (STL, 3MF, STEP). The preview on the page is a Benchy rendered with your settings.
3. Change view, projection, colour, the format label. There is no Apply button: icons are drawn a second after your last change, and a newer change cancels the older job.
4. The journal (icon at the bottom right) shows progress, you can keep working, and you can cancel. **Regenerate** draws every icon again, **Clear** removes them.

## Keep icons up to date by themselves

The window covers the files that exist now. For files that arrive later, install `stler follow`:

1. General > Follow Finder > **Install in Terminal**.
2. macOS asks once for permission to control Finder. `follow` only reads which folder is open.
3. The header shows a green tick when it runs.

In General > "When I open a file" you can also give a file its icon the moment you open it anywhere, even on a flash drive, and optionally the other models in its folder.

## STEP files

STEP needs a converter, one of two (never both):

- **FreeCAD** if you already have it (the window finds it), or
- **OpenCASCADE**: STEP page > **Install** opens Terminal with `brew install opencascade` (about 45 MB to download).

STEP stays off until the chosen one is found.

## Updating

General > About checks GitHub for a newer release (once a day, can be switched off), or press **Check for updates**. In Terminal: `stler update`.
