import SwiftUI
import AppKit

private extension ViewAngle {
    var title: String { self == .iso ? "Isometric" : rawValue.capitalized }
}

private extension LabelCorner {
    var title: String {
        switch self {
        case .off: "Off"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }
}

private extension FileType {
    var symbol: String {
        switch self {
        case .stl: "cube.fill"
        case .threeMF: "square.stack.3d.up.fill"
        case .step: "cube.transparent.fill"
        }
    }
}

/// Lowercase `#rrggbb` for a colour picked in the UI.
private func hexString(_ color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB) ?? color
    return String(format: "#%02x%02x%02x", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
}

/// Rounded coloured tile with a white symbol, like the icons in System Settings.
private struct SidebarIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 5))
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private var selection: Binding<SettingsModel.Page?> {
        Binding(get: { model.page }, set: { if let page = $0 { model.page = page } })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                Label { Text("General") } icon: { SidebarIcon(symbol: "gearshape.fill", tint: .gray) }
                    .tag(SettingsModel.Page.general)
                Section("File types") {
                    ForEach(FileType.allCases, id: \.self) { type in
                        Label { Text(type.title) } icon: { SidebarIcon(symbol: type.symbol, tint: sidebarTint(type)) }
                            .tag(SettingsModel.Page.type(type))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            VStack(spacing: 0) {
                detail
                Divider()
                if model.showJournal { journalPanel }
                footer
            }
            .navigationTitle(title)
        }
        .frame(minWidth: 780, minHeight: 560)
        .confirmationDialog(confirmationTitle, isPresented: pendingBinding, titleVisibility: .visible, presenting: model.pending) { pending in
            Button(pending.action == .clear ? "Clear" : "Apply", role: pending.action == .clear ? .destructive : nil) { model.confirmPending() }
        } message: { pending in
            Text(confirmationMessage(pending))
        }
    }

    /// The type's own colour, gray while the type is switched off.
    private func sidebarTint(_ type: FileType) -> Color {
        let style = model.config[type]
        return style.enabled && (type != .step || model.stepReady) ? Color(nsColor: style.nsColor) : .gray
    }

    private var title: String {
        if case .type(let type) = model.page { return type.title }
        return "General"
    }

    @ViewBuilder private var detail: some View {
        switch model.page {
        case .general: generalPage
        case .type(let type): typePage(type)
        }
    }

    // MARK: pages

    private var generalPage: some View {
        Form {
            Section("Where Clear and Apply work") {
                Picker("Scope", selection: scopeSelection) {
                    Text("Chosen folders").tag(Config.Scope.folder)
                    Text("Home folder").tag(Config.Scope.home)
                }
                .pickerStyle(.segmented)
                if model.config.scope == .folder {
                    ForEach(Array(model.config.scopeFolders.enumerated()), id: \.offset) { index, folder in
                        HStack {
                            Text(folder).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button { model.removeScopeFolder(at: index) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Button("Add folders...") { model.addScopeFolders() }
                        if model.config.scopeFolders.isEmpty {
                            Text("No folders yet").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(homeSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Follow Finder") {
                Picker("Depth", selection: $model.config.followDepth) {
                    Text("Open folder only").tag(1)
                    ForEach(2...5, id: \.self) { Text("\($0) levels").tag($0) }
                    Text("Unlimited").tag(0)
                }
                Text("How deep `stler follow` goes into a folder when you open it in Finder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.estimateHomeIfNeeded() }
        .confirmationDialog("Use your home folder as the scope?", isPresented: $model.confirmingHome, titleVisibility: .visible) {
            Button("Use home folder") { model.confirmHomeScope() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(homeSummary)
        }
    }

    /// Switching to the home folder goes through a confirmation; every other change applies at once.
    private var scopeSelection: Binding<Config.Scope> {
        Binding(
            get: { model.config.scope },
            set: { scope in
                if scope == .home, model.config.scope != .home { model.proposeHomeScope() } else { model.config.scope = scope }
            })
    }

    private var homeSummary: String {
        guard let estimate = model.homeEstimate else { return "Counting model files in your home folder ..." }
        let parts = FileType.allCases.map { "\($0.title) \(estimate[$0] ?? 0)" }.joined(separator: ", ")
        let total = estimate.values.reduce(0, +)
        return "About \(total) model files in your home folder (\(parts)), counted from the Spotlight index, so unindexed files are missed. Clear and Apply still ask for confirmation before they run."
    }

    private func typePage(_ type: FileType) -> some View {
        Form {
            Section {
                previewHeader
            }
            if type == .step { freecadSection }
            Section {
                Toggle("Show icons for \(type.title) files", isOn: enabledBinding(type))
                    .disabled(type == .step && !model.stepReady)
            }
            if model.config[type].enabled {
                Section("Appearance") {
                    Picker("View", selection: style(type, \.view)) {
                        ForEach(ViewAngle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Projection", selection: style(type, \.projection)) {
                        ForEach(Projection.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Toggle("System default colour", isOn: systemColor(type))
                    ColorPicker("Colour", selection: colorBinding(type, \.color), supportsOpacity: false)
                        .disabled(model.config[type].color == "system")
                    if type == .threeMF { modelColorsSlider(type) }
                    if type != .stl { limitPicker(type) }
                }
                labelSection(type)
                Section("Actions") {
                    HStack {
                        Button("Clear...") { model.request(.clear, for: type) }
                        Button("Apply") { model.request(.apply, for: type) }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                        Text(scopeDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .disabled(model.busy)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// How much of the colours stored in the file shows instead of the single fill colour.
    private func modelColorsSlider(_ type: FileType) -> some View {
        let percent = Binding<Double>(get: { Double(model.config[type].modelColors) }, set: { model.config[type].modelColors = Int($0) })
        return VStack(alignment: .leading, spacing: 2) {
            LabeledContent("Model colours") {
                HStack {
                    Slider(value: percent, in: 0...100, step: 5).frame(width: 180)
                    Text("\(model.config[type].modelColors)%").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }
            Text("0% paints everything with the fill colour. Higher values show the colours stored in the file (3MF materials, Bambu/Orca filaments); parts without a colour keep the fill.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 3MF: how many plates to show. STEP: how many parts of an assembly (a few big parts read better than hundreds of tiny ones).
    private func limitPicker(_ type: FileType) -> some View {
        let choices = type == .threeMF ? [1, 2, 3, 4, 6, 8] : [5, 10, 25, 50, 100, 250]
        let current = model.config[type].limit
        return Picker(type == .threeMF ? "Plates to show" : "Parts to show", selection: style(type, \.limit)) {
            Text("All").tag(0)
            ForEach(choices + (current == 0 || choices.contains(current) ? [] : [current]), id: \.self) { Text("First \($0)").tag($0) }
        }
    }

    private var freecadSection: some View {
        Section("STEP engine") {
            Picker("Convert with", selection: $model.config.stepEngine) {
                ForEach(StepEngine.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if model.config.stepEngine == .freecad {
                LabeledContent("freecadcmd") {
                    Text(model.freecad ?? "Not found")
                        .foregroundStyle(model.freecad == nil ? .orange : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Find automatically") { model.searchFreecad() }
                    Button("Choose...") { model.chooseFreecad() }
                    if !model.config.freecadPath.isEmpty {
                        Button("Forget") { model.config.freecadPath = "" }
                    }
                }
                .disabled(model.busy)
            } else {
                LabeledContent("OpenCASCADE") {
                    Text(OpenCascade.prefix ?? "Not installed")
                        .foregroundStyle(model.stepReady ? Color.secondary : Color.orange)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    if !model.stepReady { Button("Install (45 MB download)") { model.installOpenCascade() } }
                    Button("Check again") { model.checkOpenCascade() }
                }
            }
            Text(model.config.stepEngine == .freecad
                ? "STEP files are converted with FreeCAD (about 2 GB). Use either FreeCAD or OpenCASCADE, not both."
                : "STEP files are converted with the OpenCASCADE library, installed by Homebrew in Terminal. Use either FreeCAD or OpenCASCADE, not both.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .onAppear { if model.config.stepEngine == .freecad, model.freecad == nil { model.searchFreecad(silent: true) } }
    }

    private func labelSection(_ type: FileType) -> some View {
        Section("Format label") {
            Picker("Position", selection: label(type, \.corner)) {
                ForEach(LabelCorner.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            if model.config[type].label.corner != .off {
                ColorPicker("Text colour", selection: colorBinding(type, \.label.textColor), supportsOpacity: false)
                ColorPicker("Background colour", selection: colorBinding(type, \.label.backgroundColor), supportsOpacity: false)
                Slider(value: radiusBinding(type), in: 0...50, step: 1) { Text("Corner radius") }
                Slider(value: label(type, \.opacity), in: 0...1) { Text("Opacity") }
            }
        }
    }

    private var previewHeader: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Group {
                    if let preview = model.preview {
                        Image(nsImage: preview).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary).overlay(Text("No sample").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 200, height: 200)
                HStack {
                    Text(model.sample?.lastPathComponent ?? "No sample").font(.callout).lineLimit(1).truncationMode(.middle)
                    Button("Choose sample...") { model.chooseSample() }.controlSize(.small)
                }
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                model.showJournal.toggle()
            } label: {
                Label(model.activeJobs > 0 ? "\(model.activeJobs)" : "", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderless)
            .help("Journal")
            if model.busy { ProgressView().controlSize(.small) }
            Text(model.status).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
    }

    /// One stream, oldest at the top: finished, the running job (highlighted), then the queued ones.
    private var journalPanel: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.journal.isEmpty {
                        Text("Nothing yet. Apply, Clear and `stler follow` show up here.").font(.callout).foregroundStyle(.secondary).padding(8)
                    }
                    ForEach(model.journal) { job in journalRow(job).id(job.id) }
                }
                .padding(8)
            }
            .frame(height: 170)
            .background(.quaternary.opacity(0.4))
            .onChange(of: model.journal) { journal in
                if let target = journal.first(where: { $0.state == .running }) ?? journal.last { reader.scrollTo(target.id) }
            }
        }
        .overlay(alignment: .top) { Divider() }
    }

    private func journalRow(_ job: Job) -> some View {
        HStack(alignment: .top, spacing: 8) {
            switch job.state {
            case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .running: ProgressView().controlSize(.small)
            case .queued: Image(systemName: "clock").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title).font(.callout.weight(job.state == .running ? .semibold : .regular))
                switch job.state {
                case .done: Text(job.summary).font(.caption).foregroundStyle(.secondary)
                case .running:
                    if job.total > 0 { ProgressView(value: Double(job.done), total: Double(job.total)) }
                    Text("\(job.done)/\(job.total)  \(job.current)").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                case .queued: Text("Waiting").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(job.state == .running ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: bindings

    private func style<T>(_ type: FileType, _ keyPath: WritableKeyPath<TypeStyle, T>) -> Binding<T> {
        Binding(get: { model.config[type][keyPath: keyPath] }, set: { model.config[type][keyPath: keyPath] = $0 })
    }

    /// STEP reads as off (and cannot be switched on) while FreeCAD is missing.
    private func enabledBinding(_ type: FileType) -> Binding<Bool> {
        Binding(
            get: { model.config[type].enabled && (type != .step || model.stepReady) },
            set: { model.config[type].enabled = $0 })
    }

    private func label<T>(_ type: FileType, _ keyPath: WritableKeyPath<LabelStyle, T>) -> Binding<T> {
        Binding(get: { model.config[type].label[keyPath: keyPath] }, set: { model.config[type].label[keyPath: keyPath] = $0 })
    }

    private func radiusBinding(_ type: FileType) -> Binding<Double> {
        Binding(get: { Double(model.config[type].label.cornerRadius) }, set: { model.config[type].label.cornerRadius = Int($0.rounded()) })
    }

    private func systemColor(_ type: FileType) -> Binding<Bool> {
        Binding(get: { model.config[type].color == "system" }, set: { model.config[type].color = $0 ? "system" : type.defaultColor })
    }

    private func colorBinding(_ type: FileType, _ keyPath: WritableKeyPath<TypeStyle, String>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: Config.parseColor(model.config[type][keyPath: keyPath]) ?? .gray) },
            set: { model.config[type][keyPath: keyPath] = hexString(NSColor($0)) })
    }

    private var scopeDescription: String {
        switch model.config.scope {
        case .home: "in your home folder"
        case .folder:
            switch model.config.scopeFolders.count {
            case 0: "add a folder in General"
            case 1: "in \(model.config.scopeFolders[0])"
            default: "in \(model.config.scopeFolders.count) folders"
            }
        }
    }

    // MARK: confirmation

    private var pendingBinding: Binding<Bool> {
        Binding(get: { model.pending != nil }, set: { if !$0 { model.pending = nil } })
    }

    private var confirmationTitle: String {
        guard let pending = model.pending else { return "" }
        let count = "\(pending.files.count) \(pending.type.title) files"
        return pending.action == .clear ? "Remove STLer icons from \(count)?" : "Apply the \(pending.type.title) settings to \(count)?"
    }

    private func confirmationMessage(_ pending: SettingsModel.Pending) -> String {
        if pending.action == .clear { return "Only icons set by STLer are removed. Icons you set yourself stay." }
        return model.config.scope == .home
            ? "This walks your whole home folder and may take a while. Icons set by other tools on these files are replaced."
            : "Icons set by other tools on these files are replaced."
    }
}
