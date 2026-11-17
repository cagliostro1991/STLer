import SwiftUI

@main
struct STyLerApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        Window("STyLer", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
