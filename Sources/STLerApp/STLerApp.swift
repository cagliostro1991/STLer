import SwiftUI

@main
struct STLerApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        Window("STLer", id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 880, height: 660)
    }
}
