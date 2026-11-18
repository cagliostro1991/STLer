# FAQ

**Does it change my files?**
It writes a custom icon and one small extended attribute (`dev.stler.sig`). The contents are not touched and the modification date is put back. **Clear** removes only icons that STLer made, never ones you set yourself.

**Why custom icons and not Quick Look thumbnails?**
macOS has a built-in provider for STL and does not let an app override it (tested). A custom icon on each file is the way to change what Finder shows.

**Does it send anything anywhere?**
No. The only network request is the optional update check, which asks GitHub for the list of STLer releases once a day at most. You can switch it off in General > About.

**Does it work on external drives and network shares?**
Yes for the window and for the open Finder folder. On FAT and exFAT drives macOS keeps the icon in a hidden `._name` file next to the model. "When I open a file" only sees places that Spotlight indexes.

**What is `stler follow` and do I need it?**
A small background helper that gives new and changed files their icons by itself. Without it, icons appear only for the folders in the window's scope. See [Getting started](Getting-Started).

**Which file types are supported? Can you add mine?**
STL, 3MF and STEP/STP. The traffic-light list of next candidates is in the [README](https://github.com/cagliostro1991/STLer#formats). Ask for another one with the [format request form](https://github.com/cagliostro1991/STLer/issues/new?template=format_request.yml).

**3MF from Bambu Studio or Orca shows a pile of parts. How do I get one plate?**
3MF page > "Plates to show": First 1, 2, 3 or All. The "Model colours" slider blends the colours stored in the file with your fill colour.

**A big STEP assembly looks like a blob.**
STEP page > "Parts to show": the first N parts of the assembly in file order.

**Why is the app not notarized?**
Notarization needs a paid Apple Developer account, which this beta does not have yet. See [Getting started](Getting-Started) for the one-time Open step.

**How do I remove everything?**
Clear on every type page (removes the icons), General > Follow Finder > Stop, or `stler uninstall` (removes the LaunchAgent; the copy in `~/.local/bin` and the config stay), then delete the app.
