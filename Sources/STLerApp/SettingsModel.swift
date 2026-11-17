import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Editable config for the settings window: saves on every change, renders the live preview and runs Clear/Apply off the main thread.
final class SettingsModel: ObservableObject {
    enum Page: Hashable {
        case general
        case type(FileType)
    }

    enum Action { case clear, apply }

    /// A Clear or Apply waiting for the user's confirmation, with the files it would touch.
    struct Pending: Identifiable {
        let id = UUID()
        let type: FileType
        let action: Action
        let files: [String]
    }

    @Published var config = Config.load() {
        didSet {
            guard config != oldValue else { return }
            try? config.save()
            if config.freecadPath != oldValue.freecadPath { refreshFreecad() }
            refreshPreview()
        }
    }
    @Published var page = Page.general {
        didSet { refreshPreview() }
    }
    @Published private(set) var preview: NSImage?
    @Published private(set) var sample: URL?
    @Published private(set) var status = ""
    @Published private(set) var busy = false
    /// 0...1 while a batch is running, `nil` otherwise.
    @Published private(set) var progress: Double?
    @Published var pending: Pending?
    /// Resolved `freecadcmd`, `nil` when FreeCAD cannot be found (STEP is then off and cannot be enabled).
    @Published private(set) var freecad: String?
    /// Spotlight estimate of model files per type under the home folder; `nil` while counting or not requested.
    @Published private(set) var homeEstimate: [FileType: Int]?
    /// Set while the user is asked to confirm switching the scope to the home folder.
    @Published var confirmingHome = false

    private let queue = DispatchQueue(label: "stler.render", qos: .userInitiated)
    private var previewToken = 0

    init() {
        sample = Bundle.main.url(forResource: "3DBenchy", withExtension: "stl")
        refreshFreecad()
        refreshPreview()
    }

    /// Type whose style the preview shows: the open page, STL on the general page.
    var previewType: FileType {
        if case .type(let type) = page { return type }
        return .stl
    }

    func chooseSample() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["stl", "3mf"].compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sample = url
        refreshPreview()
    }

    func addScopeFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = (url.path as NSString).abbreviatingWithTildeInPath
            if !config.scopeFolders.contains(path) { config.scopeFolders.append(path) }
        }
    }

    func removeScopeFolder(at index: Int) {
        config.scopeFolders.remove(at: index)
    }

    /// Looks up FreeCAD without searching the disk and switches STEP off when it is missing.
    func refreshFreecad() {
        freecad = StepConverter.executable(config.freecadPath)
        if freecad == nil, config.step.enabled { config.step.enabled = false }
    }

    /// Searches the usual locations and the Spotlight index for FreeCAD and stores what it finds in the config.
    func searchFreecad(silent: Bool = false) {
        if !silent { status = "Searching for FreeCAD ..." }
        busy = !silent
        DispatchQueue.global(qos: .userInitiated).async {
            let found = StepConverter.search()
            DispatchQueue.main.async {
                self.busy = false
                if let found {
                    self.config.freecadPath = found
                    self.refreshFreecad()
                    self.status = "Found FreeCAD: \(found)"
                } else if !silent {
                    self.status = "FreeCAD not found. Install it, or choose freecadcmd (or FreeCAD.app) by hand."
                }
            }
        }
    }

    func chooseFreecad() {
        let panel = NSOpenPanel()
        panel.message = "Choose freecadcmd or FreeCAD.app"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension == "app" { url = url.appendingPathComponent("Contents/Resources/bin/freecadcmd") }
        if let error = config.set("freecadPath", url.path) { status = error } else { refreshFreecad(); status = "FreeCAD set: \(url.path)" }
    }

    /// Asks for confirmation (with a quick file count) before the scope becomes the home folder.
    func proposeHomeScope() {
        confirmingHome = true
        estimateHome()
    }

    func confirmHomeScope() {
        config.scope = .home
        confirmingHome = false
    }

    func estimateHomeIfNeeded() {
        if config.scope == .home, homeEstimate == nil { estimateHome() }
    }

    private func estimateHome() {
        homeEstimate = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let estimate = FileScanner.estimate(in: NSHomeDirectory())
            DispatchQueue.main.async { self.homeEstimate = estimate }
        }
    }

    /// Counts the files first, then asks for confirmation (always for Clear, for Apply on the home folder) or runs right away.
    func request(_ action: Action, for type: FileType) {
        let paths = config.scopePaths
        guard !paths.isEmpty else { status = "Add a folder first (General)."; return }
        let home = config.scope == .home
        let needsConfirmation = action == .clear || home
        busy = true
        status = "Counting \(type.title) files ..."
        queue.async {
            let files = home ? FileScanner.spotlight(type, in: NSHomeDirectory()) : FileScanner.scan(paths, formats: [type.rawValue])
            DispatchQueue.main.async {
                self.busy = false
                if files.isEmpty {
                    self.status = "No \(type.title) files in the chosen scope."
                } else if needsConfirmation {
                    self.status = ""
                    self.pending = Pending(type: type, action: action, files: files)
                } else {
                    self.run(action, type, files)
                }
            }
        }
    }

    func confirmPending() {
        guard let pending else { return }
        self.pending = nil
        run(pending.action, pending.type, pending.files)
    }

    private func run(_ action: Action, _ type: FileType, _ files: [String]) {
        let config = config
        switch action {
        case .clear:
            work("Clearing \(files.count) \(type.title) files ...") { _ in
                let r = IconBatch.reset(files)
                return "Cleared \(r.reset) icons, left \(r.untouched) untouched (not set by STLer)."
            }
        case .apply:
            work("Rendering \(files.count) \(type.title) files ...") { progress in
                let r = IconBatch.apply(files, config: config, onProgress: progress)
                return "Rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)."
            }
        }
    }

    private func refreshPreview() {
        guard let url = sample else { preview = nil; return }
        previewToken += 1
        let token = previewToken, type = previewType
        let options = IconRenderer.Options(style: config[type], firstPlateOnly: config.firstPlateOnly, labelText: type.title)
        queue.async {
            let image = IconRenderer.render(url, size: CGSize(width: 384, height: 384), options: options)
            DispatchQueue.main.async { if token == self.previewToken { self.preview = image } }
        }
    }

    private func work(_ title: String, _ job: @escaping (_ progress: @escaping (Int, Int) -> Void) -> String) {
        busy = true
        status = title
        queue.async {
            let result = job { done, total in
                DispatchQueue.main.async { self.progress = Double(done) / Double(total) }
            }
            DispatchQueue.main.async {
                self.status = result
                self.busy = false
                self.progress = nil
            }
        }
    }
}
