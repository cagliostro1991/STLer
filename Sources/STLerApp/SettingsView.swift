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
                footer
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { agentButton }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.showWelcome = true } label: { Image(systemName: "questionmark.circle") }.help("What is STLer?")
                }
            }
        }
        .frame(minWidth: 780, minHeight: 560)
        .sheet(isPresented: $model.showWelcome) { welcome }
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
            Section("When I open a file") {
                Toggle("Give a file its icon when I open it", isOn: $model.config.followOpened)
                Text("Works wherever the file is: in any folder, or on a connected drive such as a flash drive, even when no Finder window shows it. The icon appears a few seconds after you open the file. It needs stler follow to be running (see below), and it only sees places that Spotlight indexes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Also the other models in its folder", isOn: $model.config.followOpenedFolder)
                    .disabled(!model.config.followOpened)
                Text("After the file itself, the other STL, 3MF and STEP files that lie in the same folder get icons too. Only that one folder is used, subfolders are left alone, and at most \(FileScanner.siblingLimit) files at a time, so opening one file never starts a long job.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if model.config.followOpened, model.agent != .running {
                    Label("stler follow is not running, so nothing happens yet.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            Section("Follow Finder") {
                LabeledContent("stler follow") {
                    Text(followStatusText)
                        .foregroundStyle(model.agent == .running ? Color.green : Color.orange)
                }
                HStack {
                    if model.agent == .notInstalled {
                        Button("Install in Terminal") { model.installFollow() }
                        Button("Check again") { model.checkFollow() }
                    } else {
                        Button(model.agent == .running ? "Stop" : "Start") { model.toggleFollow() }
                        Button("Reinstall in Terminal") { model.installFollow() }
                    }
                }
                Text(Self.followExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("Depth", selection: $model.config.followDepth) {
                    Text("Open folder only").tag(1)
                    ForEach(2...5, id: \.self) { Text("\($0) levels").tag($0) }
                    Text("Unlimited").tag(0)
                }
                Text("How deep `stler follow` goes into a folder when you open it in Finder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("STLer") { Text(AppVersion.current).foregroundStyle(.secondary) }
                HStack {
                    Button("Check for updates") { model.checkForUpdate() }.disabled(model.checkingUpdate)
                    if model.checkingUpdate { ProgressView().controlSize(.small) }
                    switch model.update {
                    case .upToDate?: Text("You have the latest version.").foregroundStyle(.secondary)
                    case .available(let release)?:
                        Link("Version \(release.tag) is available: open the download page", destination: release.url)
                    case .failed(let message)?: Text(message).foregroundStyle(.orange)
                    case nil: EmptyView()
                    }
                }
                Toggle("Check for updates when the window opens", isOn: $model.config.checkUpdates)
                Text("Asks GitHub for the list of public releases of STLer, at most once a day. Nothing about you or your files is sent.")
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
                if !model.hasUnappliedChanges(type) {
                    Section("Actions") { actionsPanel(type) }
                }
            }
        }
        .formStyle(.grouped)
        .overlay(alignment: .bottom) {
            if model.hasUnappliedChanges(type) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("These settings are not applied to your files yet", systemImage: "circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                    actionsPanel(type)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.4)))
                .shadow(radius: 8, y: 2)
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.hasUnappliedChanges(type))
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
        let choices = type == .threeMF ? [1, 2, 3] : [5, 10, 25, 50, 100, 250]
        let current = model.config[type].limit
        return Picker(type == .threeMF ? "Plates to show" : "Parts to show", selection: style(type, \.limit)) {
            Text("All").tag(0)
            ForEach(choices + (current == 0 || choices.contains(current) ? [] : [current]), id: \.self) { Text("First \($0)").tag($0) }
        }
    }

    /// Clear and Apply with the place they work on. Sits in the form, and floats above it while changes are waiting.
    private func actionsPanel(_ type: FileType) -> some View {
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
                    if !model.stepReady {
                        Button("Install (45 MB download)") { model.installOpenCascade() }
                        Button("Check again") { model.checkOpenCascade() }
                    }
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
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary).overlay(Text(model.previewNote ?? "...").font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(8))
                    }
                }
                .frame(width: 200, height: 200)
                .opacity(model.previewBusy ? 0.45 : 1)
                .overlay { if model.previewBusy { ProgressView().controlSize(.large) } }
                HStack {
                    Text(model.sample?.lastPathComponent ?? "No sample").font(.callout).lineLimit(1).truncationMode(.middle)
                    Button("Choose sample...") { model.chooseSample() }.controlSize(.small)
                    if model.hasCustomSample { Button("Benchy") { model.resetSample() }.controlSize(.small).help("Back to the bundled sample") }
                }
            }
            Spacer()
        }
    }

    private func welcomeBlock(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Shown on the first launch: what the app is, why it works the way it does, why there is a command line tool.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to STLer").font(.title.bold())
            welcomeBlock("cube.transparent", "What it does",
                "macOS shows STL, 3MF and STEP files with a plain generic icon. STLer draws a small picture of the model itself and sets it as the file's icon in Finder, so you see what is inside before you open it.")
            welcomeBlock("paintbrush", "How it works",
                "The model is rendered off-screen from the angle and in the colour you choose for each file type here. The picture is stored as the file's own custom icon. The file's contents and modification date stay as they were, and Clear removes the icons again.")
            welcomeBlock("photo.on.rectangle", "Why icons and not previews",
                "macOS has its own thumbnail for STL files and an app cannot replace it. Setting a custom icon on each file is the only way to change what Finder shows.")
            welcomeBlock("terminal", "Why there is a command line tool",
                "Apply in this window only covers the files that exist right now. Files that arrive later, such as a download, a folder you open in Finder or a file you open from a flash drive, need something that keeps watching in the background, also when this window is closed. That is stler, a small command line program. Install puts a copy in ~/.local/bin and macOS starts it at login. The first time it asks for permission to see which folder Finder shows.")
            HStack {
                Spacer()
                Button("Not now") { model.dismissWelcome(setup: false) }
                Button("Set up stler follow") { model.dismissWelcome(setup: true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private static let followExplanation = "stler follow is a small background helper. When you open a folder in Finder it gives new and changed STL, 3MF and STEP files their icons right away, so you do not have to press Apply. It starts at login, uses almost no resources, and needs permission to see which folder Finder shows (macOS asks the first time)."

    private var followStatusText: String {
        model.agent == .running ? "Running" : model.agent == .stopped ? "Installed, not running" : "Not installed"
    }

    /// Header reminder: a green tick when `stler follow` runs as a LaunchAgent, an orange warning when it is missing or stopped.
    /// Click shows what it is and leads to General, where it can be installed.
    private var agentButton: some View {
        Button { model.showAgentInfo.toggle() } label: {
            Label("stler", systemImage: model.agent == .running ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(model.agent == .running ? Color.green : Color.orange)
        }
        .help(model.agent == .running ? "stler follow is installed and running" : "stler follow is not running")
        .popover(isPresented: $model.showAgentInfo, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Label("stler follow: \(followStatusText.lowercased())", systemImage: model.agent == .running ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(model.agent == .running ? Color.green : Color.orange)
                Text(Self.followExplanation).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(model.agent == .running ? "Open General" : "Set up in General") {
                    model.showAgentInfo = false
                    model.page = .general
                }
            }
            .padding(14)
            .frame(width: 340)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.busy { ProgressView().controlSize(.small) }
            Text(model.status).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            Button {
                model.showJournal.toggle()
            } label: {
                Label(model.activeJobs > 0 ? "\(model.activeJobs)" : "", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderless)
            .help("Journal")
            .popover(isPresented: $model.showJournal, arrowEdge: .top) { journalPanel }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
    }

    /// One stream, oldest at the top: finished, the running job (highlighted), then the queued ones.
    private var journalPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Journal").font(.headline)
                Spacer()
                Button("Clear") { model.clearJournal() }
                    .controlSize(.small)
                    .disabled(!model.journal.contains { $0.state != .running })
                    .help("Removes finished entries and cancels waiting jobs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            journalList
        }
    }

    private var journalList: some View {
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
            .frame(width: 460, height: 300)
            .onChange(of: model.journal) { journal in
                if let target = journal.first(where: { $0.state == .running }) ?? journal.last { reader.scrollTo(target.id) }
            }
        }
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
            if job.state != .done {
                Button { model.cancel(job) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(job.state == .running ? "Cancel this job" : "Remove from the queue")
            }
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
