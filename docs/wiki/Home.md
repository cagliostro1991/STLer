# STLer

STLer puts a small picture of the model on `.stl`, `.3mf` and `.step` files in macOS Finder, instead of the generic icon.

- **New here?** [Getting started](Getting-Started)
- **Something odd?** [Troubleshooting](Troubleshooting) and the [FAQ](FAQ)
- **Want to ask, suggest or report?** [Feedback and requests](Feedback-and-Requests)
- **Formats:** STL, 3MF and STEP today, others are on the traffic-light list in the [README](https://github.com/cagliostro1991/STLer#formats)

Download: [Releases](https://github.com/cagliostro1991/STLer/releases). Source and docs: [the repository](https://github.com/cagliostro1991/STLer).

## The basics in one minute

1. macOS has its own thumbnail for STL and an app cannot replace it, so STLer renders each model off-screen and sets the picture as the file's **custom icon**.
2. The **window** (`STLer.app`) sets how icons look per file type and applies them to the files that exist now (Apply), or removes them (Clear).
3. The **command line tool** (`stler`) does the same from Terminal, and `stler follow` keeps watching in the background so new files get their icons too.
4. The file's contents and modification date stay the same. Clear removes only icons STLer made.
