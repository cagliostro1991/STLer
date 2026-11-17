import Foundation

/// Journal entries written by other processes (`stler follow`), read by the settings window.
/// One small JSON file shared by both, guarded by `flock`; only the last `JobQueue.keepFinished` finished entries are kept.
enum ActivityLog {
    struct Entry: Codable, Equatable {
        var id = UUID()
        var title: String
        var running: Bool
        var done = 0
        var total = 0
        var current = ""
        var summary = ""
        /// Seconds since 1970 of the last change.
        var time = Date().timeIntervalSince1970
    }

    /// `STLER_LOG` overrides the path (tests).
    static var url: URL {
        ProcessInfo.processInfo.environment["STLER_LOG"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/STLer/activity.json")
    }

    /// Adds the entry, or replaces the one with the same id.
    static func upsert(_ entry: Entry) {
        modify { entries in
            var entry = entry
            entry.time = Date().timeIntervalSince1970
            if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry } else { entries.append(entry) }
            let finished = entries.indices.filter { !entries[$0].running }
            for index in finished.dropLast(JobQueue.keepFinished).reversed() { entries.remove(at: index) }
        }
    }

    /// Entries as journal jobs, oldest first.
    static func jobs() -> [Job] {
        modify { _ in }.map { entry in
            var job = Job(title: entry.title)
            job.id = entry.id
            job.state = entry.running ? .running : .done
            job.done = entry.done
            job.total = entry.total
            job.current = entry.current
            job.summary = entry.summary
            job.finishedAt = Date(timeIntervalSince1970: entry.time)
            return job
        }
    }

    /// Reads, edits and writes the file under an exclusive lock. A missing or broken file counts as empty.
    @discardableResult
    private static func modify(_ edit: (inout [Entry]) -> Void) -> [Entry] {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_RDWR | O_CREAT, 0o644)
        guard descriptor >= 0 else { return [] }
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        var entries = (try? JSONDecoder().decode([Entry].self, from: handle.readDataToEndOfFile())) ?? []
        let before = entries
        edit(&entries)
        if entries != before, let data = try? JSONEncoder().encode(entries) {
            try? handle.truncate(atOffset: 0)
            try? handle.seek(toOffset: 0)
            try? handle.write(contentsOf: data)
        }
        return entries
    }
}
