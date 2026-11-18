import SwiftUI

@main
struct STLerApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        Window("STLer", id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 880, height: 660)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") { model.checkForUpdate() }
                    .disabled(model.checkingUpdate)
            }
            CommandMenu("Icons") {
                Button("Regenerate") {
                    if let type = model.currentType {
                        model.scheduleApply(type, delay: 0, force: true)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canRun)
                Button("Clear...") {
                    if let type = model.currentType { model.requestClear(for: type) }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!canRun)
                Divider()
                Button("Show Journal") { model.showJournal.toggle() }
                    .keyboardShortcut("j", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) {
                Button("What Is STLer?") { model.showWelcome = true }
                Link(
                    "STLer Help",
                    destination: URL(string: "https://github.com/\(UpdateChecker.repository)/wiki")!
                )
                Link(
                    "Report a Problem...",
                    destination: Feedback.issueURL(template: "bug_report.yml"))
            }
        }
    }

    /// Apply and Clear work on the file type whose page is open and switched on.
    private var canRun: Bool {
        guard let type = model.currentType else { return false }
        return model.config[type].enabled && !model.busy
    }
}
