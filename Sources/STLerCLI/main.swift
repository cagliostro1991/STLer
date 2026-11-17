import AppKit

enum Command: String { case run, follow, reset, config, install, uninstall }

setvbuf(stdout, nil, _IOLBF, 0)
var arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first.flatMap(Command.init(rawValue:))
if command != nil { arguments.removeFirst() }

do {
    switch command ?? .run {
    case .run: try runIcons(arguments)
    case .follow: follow()
    case .reset: try reset(arguments)
    case .config: try configure(arguments)
    case .install: try LaunchAgent.install()
    case .uninstall: LaunchAgent.uninstall()
    }
} catch let error as CLIError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
