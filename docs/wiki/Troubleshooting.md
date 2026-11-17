# Troubleshooting

## An icon did not appear or is grey
- Is the type switched on, and was **Apply** pressed after the last change? The floating panel says so when settings are not applied yet.
- The file is in a folder that is not in General's scope? Apply only works inside the scope. `stler follow` works on any folder you open in Finder.
- Finder caches icons. Close and reopen the window, or move away and back to the folder.
- The journal shows a failure? Open it (bottom right) and read the line. Copy it into a [bug report](https://github.com/cagliostro1991/STLer/issues/new?template=bug_report.yml).

## An icon is not updated for a file I moved or copied
Copies to other volumes, iCloud or archives can keep our signature and lose the icon. STLer notices that (a file counts as up to date only with a real icon) and renders it again on the next Apply or when `follow` sees the folder. If it still does not, send a bug report with where the file came from.

## The header shows a warning next to "stler"
`stler follow` is not installed or not running. Click it, then **Set up in General**, then **Install in Terminal**. If it says "Installed, not running", press **Start**. After updating the app, press **Reinstall in Terminal** so the background tool gets the new version too.

## `follow` does nothing after I add a file
It needs to be running (green tick). It looks at the folder open in front in Finder, and rescans it when files are added to that folder directly. A file added deeper in a subfolder is picked up when you open that folder. In General > "When I open a file" you can also render files as you open them anywhere.

## A huge 3MF takes minutes
Some projects contain hundreds of megabytes of XML. They are rendered one at a time, smaller files first. You can cancel a job in the journal.

## STEP stays off
The chosen converter was not found. STEP page: for FreeCAD press **Find automatically** or **Choose...**, for OpenCASCADE press **Install** and, when Terminal is done, **Check again**. Only one converter is used at a time.

## macOS says the app cannot be opened
The beta is not notarized. Right-click the app > **Open**, or `xattr -dr com.apple.quarantine /Applications/STLer.app`.

## Where are the logs and settings?
- Settings: `~/.config/stler/config.json` (`stler config get` prints them)
- `follow` log: `~/Library/Logs/stler.log`
- Journal data: `~/Library/Logs/STLer/activity.json`
- STEP cache and helper: `~/Library/Caches/stler`, `~/Library/Application Support/STLer`

## Still stuck?
Ask in [Discussions](https://github.com/cagliostro1991/STLer/discussions/new?category=q-a) or file a [bug report](https://github.com/cagliostro1991/STLer/issues/new?template=bug_report.yml).
