import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Holds the editable config, saves it on every change and renders the live preview.
final class SettingsModel: ObservableObject {
    enum ResetScope { case finderFolder, watched }

    @Published var config = Config.load() {
        didSet {
            guard config != oldValue else { return }
            try? config.save()
            refreshPreview()
        }
    }
    @Published var preview: NSImage?
    @Published var sample: URL?
    @Published var status = ""
    @Published var busy = false
    @Published var pendingReset: ResetScope?

    private let queue = DispatchQueue(label: "styler.render", qos: .userInitiated)
    private var previewToken = 0

    init() {
        if let folder = activeFinderFolder() {
            sample = collectFiles([folder], formats: config.formats.filter { $0 != "step" }, maxDepth: 2).first.map { URL(fileURLWithPath: $0) }
        }
        refreshPreview()
    }

    func refreshPreview() {
        guard let url = sample else { preview = nil; return }
        previewToken += 1
        let token = previewToken, c = config
        queue.async {
            let img = parseColor(c.color).flatMap { render(stl: url, size: CGSize(width: 384, height: 384), view: c.view, color: $0, firstPlateOnly: c.firstPlateOnly, badge: c.badge) }
            DispatchQueue.main.async { if token == self.previewToken { self.preview = img } }
        }
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
        guard let folder = activeFinderFolder() else { status = "No Finder window, or Automation access to Finder was denied."; return }
        let c = config
        work("Rendering \(folder) ...") {
            let r = processFolder(folder, config: c)
            return "\(folder): rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)"
        }
    }

    func reset(_ scope: ResetScope) {
        var paths = config.watch
        if scope == .finderFolder {
            guard let folder = activeFinderFolder() else { status = "No Finder window, or Automation access to Finder was denied."; return }
            paths = [folder]
        }
        work("Resetting icons ...") {
            let r = resetIcons(collectFiles(paths, formats: Array(Config.supportedFormats)))
            return "Reset \(r.reset) icons, left \(r.untouched) untouched (no STyLer signature)."
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
