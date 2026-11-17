import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Editable config for the settings window: saves on every change and renders the live preview off the main thread.
final class SettingsModel: ObservableObject {
    enum ResetScope { case finderFolder, watched }

    @Published var config = Config.load() {
        didSet {
            guard config != oldValue else { return }
            try? config.save()
            refreshPreview()
        }
    }
    @Published private(set) var preview: NSImage?
    @Published private(set) var sample: URL?
    @Published private(set) var status = ""
    @Published private(set) var busy = false
    /// Set by the UI to ask for confirmation before a destructive reset.
    @Published var pendingReset: ResetScope?

    private let queue = DispatchQueue(label: "stler.render", qos: .userInitiated)
    private var previewToken = 0

    init() {
        if let folder = FinderFolder.front() {
            let formats = config.formats.filter { $0 != "step" }
            sample = FileScanner.collect([folder], formats: formats, maxDepth: 2).first.map { URL(fileURLWithPath: $0) }
        }
        refreshPreview()
    }

    func chooseSample() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["stl", "3mf"].compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sample = url
        refreshPreview()
    }

    func addWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = (url.path as NSString).abbreviatingWithTildeInPath
        if !config.watch.contains(path) { config.watch.append(path) }
    }

    func removeWatchFolder(at index: Int) {
        config.watch.remove(at: index)
    }

    func applyToFinderFolder() {
        guard let folder = FinderFolder.front() else { status = Self.noFinderMessage; return }
        let config = config
        work("Rendering \(folder) ...") {
            let r = IconBatch.applyToFolder(folder, config: config)
            return "\(folder): rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)"
        }
    }

    func reset(_ scope: ResetScope) {
        var paths = config.watch
        if scope == .finderFolder {
            guard let folder = FinderFolder.front() else { status = Self.noFinderMessage; return }
            paths = [folder]
        }
        work("Resetting icons ...") {
            let r = IconBatch.reset(FileScanner.collect(paths, formats: Array(Config.supportedFormats)))
            return "Reset \(r.reset) icons, left \(r.untouched) untouched (no STLer signature)."
        }
    }

    private static let noFinderMessage = "No Finder window, or Automation access to Finder was denied."

    private func refreshPreview() {
        guard let url = sample else { preview = nil; return }
        previewToken += 1
        let token = previewToken, options = IconRenderer.Options(config: config)
        queue.async {
            let image = IconRenderer.render(url, size: CGSize(width: 384, height: 384), options: options)
            DispatchQueue.main.async { if token == self.previewToken { self.preview = image } }
        }
    }

    private func work(_ title: String, _ job: @escaping () -> String) {
        busy = true
        status = title
        queue.async {
            let result = job()
            DispatchQueue.main.async {
                self.status = result
                self.busy = false
            }
        }
    }
}
