import SwiftUI
import AppKit

/// Lowercase `#rrggbb` for a colour picked in the UI.
func hexString(_ color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB) ?? color
    return String(format: "#%02x%02x%02x", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private let views = ["iso", "front", "back", "left", "right", "top", "bottom"]
    private let badges = [("off", "Off"), ("topLeft", "Top left"), ("topRight", "Top right"), ("bottomLeft", "Bottom left"), ("bottomRight", "Bottom right")]

    private var systemColor: Binding<Bool> {
        Binding(get: { model.config.color == "system" }, set: { model.config.color = $0 ? "system" : "#808080" })
    }

    private var customColor: Binding<Color> {
        Binding(get: { Color(nsColor: parseColor(model.config.color) ?? .systemGray) }, set: { model.config.color = hexString(NSColor($0)) })
    }

    private func format(_ ext: String) -> Binding<Bool> {
        Binding(
            get: { model.config.formats.contains(ext) },
            set: { on in
                var f = model.config.formats.filter { $0 != ext }
                if on { f.append(ext) }
                model.config.formats = f.sorted()
            })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                Section("Appearance") {
                    Picker("View", selection: $model.config.view) {
                        ForEach(views, id: \.self) { Text($0 == "iso" ? "Isometric" : $0.capitalized).tag($0) }
                    }
                    Toggle("System default colour", isOn: systemColor)
                    ColorPicker("Colour", selection: customColor, supportsOpacity: false).disabled(model.config.color == "system")
                    Picker("Format label", selection: $model.config.badge) {
                        ForEach(badges, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section("Files") {
                    Toggle("STL", isOn: format("stl"))
                    Toggle("3MF", isOn: format("3mf"))
                    Toggle("STEP (needs FreeCAD)", isOn: format("step"))
                    if model.config.formats.contains("step"), StepConverter.executable(model.config.freecadPath) == nil {
                        Text("freecadcmd not found. Install FreeCAD or set `freecadPath` in the config.").font(.callout).foregroundStyle(.orange)
                    }
                    Toggle("3MF: first plate only", isOn: $model.config.firstPlateOnly)
                    Toggle("Re-render even if up to date", isOn: $model.config.force)
                }
                Section("Follow Finder") {
                    Picker("Depth", selection: $model.config.followDepth) {
                        Text("Open folder only").tag(1)
                        ForEach(2...5, id: \.self) { Text("\($0) levels").tag($0) }
                        Text("Unlimited").tag(0)
                    }
                }
                Section("Watched folders (used by Reset)") {
                    ForEach(Array(model.config.watch.enumerated()), id: \.offset) { i, path in
                        HStack {
                            Text(path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button { model.removeWatchFolder(at: i) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    }
                    Button("Add folder...") { model.addWatchFolder() }
                }
                Section("Actions") {
                    Button("Apply to current Finder folder") { model.applyToFinderFolder() }.disabled(model.busy)
                    Button("Reset icons in current Finder folder...") { model.pendingReset = .finderFolder }.disabled(model.busy)
                    Button("Reset icons in watched folders...") { model.pendingReset = .watched }.disabled(model.busy || model.config.watch.isEmpty)
                    if !model.status.isEmpty { Text(model.status).font(.callout).foregroundStyle(.secondary) }
                }
            }
            .formStyle(.grouped)
            .frame(width: 430)

            VStack(spacing: 12) {
                Group {
                    if let preview = model.preview {
                        Image(nsImage: preview).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary).overlay(Text("No sample").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 300, height: 300)
                Text(model.sample?.lastPathComponent ?? "Choose a sample model").font(.callout).lineLimit(1).truncationMode(.middle)
                Button("Choose sample...") { model.chooseSample() }
            }
            .padding(20)
        }
        .frame(minHeight: 620)
        .confirmationDialog("Remove STyLer icons?", isPresented: Binding(get: { model.pendingReset != nil }, set: { if !$0 { model.pendingReset = nil } }), titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                if let scope = model.pendingReset { model.reset(scope) }
                model.pendingReset = nil
            }
        } message: {
            Text("Only icons set by STyLer are removed. Custom icons you set yourself stay.")
        }
    }
}
