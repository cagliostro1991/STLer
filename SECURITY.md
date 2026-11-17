# Security policy

## Supported versions

STLer is in beta. Only the latest release gets fixes.

## What matters here

STLer runs on your Mac and touches files. The parts worth a careful look:

- it writes custom icons and one extended attribute (`dev.stler.sig`) on model files, and puts the modification date back;
- `stler install` copies the tool to `~/.local/bin` and loads a LaunchAgent;
- the window can open Terminal with `brew install opencascade` or `stler install`, and it compiles a small helper with `clang++`;
- it reads STL, 3MF and STEP files that may come from the internet (a crafted file should never crash or hang the tool, or write outside its own icon data);
- the update check asks GitHub for the public release list, nothing else is sent anywhere.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting: [report a vulnerability](https://github.com/cagliostro1991/STLer/security/advisories/new). Include the version (`stler version`), macOS version, and steps or a file that reproduces it.

You can expect a first answer within about a week, this is a spare-time project. A fix is released as a new version and the advisory credits you unless you prefer not to be named.

## Not a vulnerability

The build is ad-hoc signed and not notarized yet, so macOS asks you to confirm opening it. That is known and described in the install instructions.
