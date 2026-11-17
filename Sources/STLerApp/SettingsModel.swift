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
            if config.freecadPath != oldValue.freecadPath || config.stepEngine != oldValue.stepEngine { refreshFreecad() }
            refreshPreview()
        }
    }
    @Published var page = Page.general {
        didSet { refreshPreview() }
    }
    @Published private(set) var preview: NSImage?
    /// Sample file per type: the bundled Benchy variants unless the user picked one (remembered in `UserDefaults`).
    @Published private(set) var samples: [FileType: URL] = [:]
    /// Why the preview is empty, when it is not just loading.
    @Published private(set) var previewNote: String?
    /// True while a preview is being rendered; the first render of a big 3MF takes a couple of seconds.
    @Published private(set) var previewBusy = false
    @Published private(set) var status = ""
    @Published private(set) var busy = false
    /// The journal as one stream: finished (last 10), running, queued. Includes what `stler follow` did.
    @Published private(set) var journal: [Job] = []
    @Published var showJournal = false
    /// Whether `stler follow` is installed as a LaunchAgent and running.
    @Published private(set) var agent = FollowAgent.State.notInstalled
    @Published var showAgentInfo = false
    @Published var pending: Pending?
    /// Resolved `freecadcmd`, `nil` when FreeCAD cannot be found (STEP is then off and cannot be enabled).
    @Published private(set) var freecad: String?
    /// Whether the chosen STEP engine is available; STEP is off and cannot be enabled otherwise.
    @Published private(set) var stepReady = false
    /// Spotlight estimate of model files per type under the home folder; `nil` while counting or not requested.
    @Published private(set) var homeEstimate: [FileType: Int]?
    /// Set while the user is asked to confirm switching the scope to the home folder.
    @Published var confirmingHome = false

    private let queue = DispatchQueue(label: "stler.render", qos: .userInitiated)
    private let jobQueue = JobQueue()
    private var previewToken = 0

    init() {
        for type in FileType.allCases {
            let remembered = UserDefaults.standard.string(forKey: "sample.\(type.rawValue)").map { URL(fileURLWithPath: $0) }
            samples[type] = remembered.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
                ?? Bundle.main.url(forResource: "3DBenchy", withExtension: type.sampleExtension)
        }
        refreshFreecad()
        refreshPreview()
        jobQueue.didChange = { [weak self] in DispatchQueue.main.async { self?.refreshJournal() } }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refreshJournal() }
        refreshAgent()
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refreshAgent() }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshAgent() }
    }

    func refreshAgent() {
        DispatchQueue.global(qos: .utility).async {
            let state = FollowAgent.state()
            DispatchQueue.main.async { if state != self.agent { self.agent = state } }
        }
    }

    /// Opens Terminal with `stler install`, see `FollowAgent.installInTerminal`.
    func installFollow() { status = FollowAgent.installInTerminal(appBundle: Bundle.main.bundleURL) }

    /// Stops or starts the installed agent right away, no Terminal needed.
    func toggleFollow() {
        let wasRunning = agent == .running
        status = wasRunning ? "Stopping stler follow ..." : "Starting stler follow ..."
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = wasRunning ? FollowAgent.stop() : FollowAgent.start()
            DispatchQueue.main.async {
                self.status = ok ? (wasRunning ? "stler follow stopped. It starts again at login, or press Start." : "stler follow started.") : "launchctl refused. Try Reinstall."
                self.refreshAgent()
            }
        }
    }

    func checkFollow() {
        refreshAgent()
        status = "Checking stler follow ..."
    }

    /// Merges the window's own jobs with the shared log of `stler follow`: finished ones by time, then running, then queued.
    func refreshJournal() {
        let all = jobQueue.jobs + ActivityLog.jobs()
        let finished = all.filter { $0.state == .done }.sorted { $0.finishedAt < $1.finishedAt }.suffix(JobQueue.keepFinished)
        let merged = Array(finished) + all.filter { $0.state == .running } + all.filter { $0.state == .queued }
        if merged != journal { journal = merged }
    }

    /// Jobs that are running or waiting, for the badge on the journal button.
    var activeJobs: Int { journal.filter { $0.state != .done }.count }

    /// Type whose style the preview shows: the open page, STL on the general page.
    var previewType: FileType {
        if case .type(let type) = page { return type }
        return .stl
    }

    /// Sample for the open page.
    var sample: URL? { samples[previewType] }

    /// Whether the open page shows a file the user picked instead of the bundled sample.
    var hasCustomSample: Bool { sample.map { $0 != Bundle.main.url(forResource: "3DBenchy", withExtension: previewType.sampleExtension) } ?? false }

    func chooseSample() {
        let type = previewType
        let panel = NSOpenPanel()
        panel.allowedContentTypes = type.extensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        samples[type] = url
        UserDefaults.standard.set(url.path, forKey: "sample.\(type.rawValue)")
        refreshPreview()
    }

    func resetSample() {
        let type = previewType
        UserDefaults.standard.removeObject(forKey: "sample.\(type.rawValue)")
        samples[type] = Bundle.main.url(forResource: "3DBenchy", withExtension: type.sampleExtension)
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

    /// Looks up the STEP engines without searching the disk and switches STEP off when the chosen one is missing.
    func refreshFreecad() {
        freecad = StepConverter.executable(config.freecadPath)
        stepReady = StepConverter.isReady(config)
        if !stepReady, config.step.enabled { config.step.enabled = false }
    }

    /// Opens Terminal with the OpenCASCADE install, see `OpenCascade.install`.
    func installOpenCascade() { status = OpenCascade.install() }

    func checkOpenCascade() {
        refreshFreecad()
        status = OpenCascade.prefix == nil ? "OpenCASCADE is still not installed." : "OpenCASCADE found."
        refreshPreview()
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
    /// Counts first and opens the dialog afterwards: a presented dialog keeps the text it was opened with.
    func proposeHomeScope() {
        status = "Counting model files in your home folder ..."
        estimateHome { self.status = ""; self.confirmingHome = true }
    }

    func confirmHomeScope() {
        config.scope = .home
        confirmingHome = false
    }

    func estimateHomeIfNeeded() {
        if config.scope == .home, homeEstimate == nil { estimateHome() }
    }

    private func estimateHome(then done: @escaping () -> Void = {}) {
        homeEstimate = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let estimate = FileScanner.estimate(in: NSHomeDirectory())
            DispatchQueue.main.async { self.homeEstimate = estimate; done() }
        }
    }

    /// Counts the files first, then asks for confirmation (always for Clear, for Apply on the home folder) or runs right away.
    func request(_ action: Action, for type: FileType) {
        let paths = config.scopePaths
        guard !paths.isEmpty else { status = "Add a folder first (General)."; return }
        let needsConfirmation = action == .clear || config.scope == .home
        busy = true
        status = "Counting \(type.title) files ..."
        queue.async {
            var seen = Set<String>()
            let files = paths.flatMap { FileScanner.spotlight(type, in: $0) }.filter { seen.insert($0).inserted }
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
        showJournal = true
        switch action {
        case .clear:
            jobQueue.enqueue("Clear \(type.title) icons (\(files.count) files)") { reporter in
                let r = IconBatch.reset(files, onProgress: reporter.progress)
                return "Cleared \(r.reset) icons, left \(r.untouched) untouched (not set by STLer)."
            }
        case .apply:
            jobQueue.enqueue("Apply \(type.title) (\(files.count) files)") { reporter in
                let r = IconBatch.apply(files, config: config, onProgress: reporter.progress)
                return "Rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)." + (r.messages.isEmpty ? "" : " " + r.messages.prefix(3).joined(separator: "; "))
            }
        }
    }

    private func refreshPreview() {
        previewToken += 1
        let token = previewToken, type = previewType, config = config
        previewBusy = false
        guard let url = sample else { preview = nil; previewNote = "No sample"; return }
        if type == .step, !StepConverter.isReady(config) { preview = nil; previewNote = "Choose a STEP engine above to see the preview"; return }
        previewNote = nil
        previewBusy = true
        let options = IconRenderer.Options(style: config[type], labelText: type.title)
        queue.async {
            guard token == self.previewToken else { return }
            let source = type == .step ? StepConverter.convert([url.path], config: config).urls[url.path] : url
            let image = source.flatMap { IconRenderer.render($0, size: CGSize(width: 384, height: 384), options: options) }
            DispatchQueue.main.async {
                guard token == self.previewToken else { return }
                self.preview = image
                self.previewBusy = false
                if image == nil { self.previewNote = "The sample could not be rendered" }
            }
        }
    }
}
