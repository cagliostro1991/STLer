import Foundation

/// Decides when an Apply of a file type starts. A change waits for a quiet moment, and a newer change
/// of the same type drops the older run, whether it still waits, is being counted or already runs.
final class ApplyScheduler {
    private let lock = NSLock()
    private var timers: [FileType: DispatchWorkItem] = [:]
    private var generations: [FileType: Int] = [:]
    private let queue: DispatchQueue
    private let supersede: (FileType) -> Void
    private let start: (FileType, Bool) -> Void

    /// - Parameters:
    ///   - queue: Where `start` runs.
    ///   - supersede: Drops the run a newer `schedule` or a `cancel` makes obsolete (cancels its job).
    ///   - start: Begins an Apply of the type after the quiet period; the flag is Regenerate.
    init(
        queue: DispatchQueue = .main,
        supersede: @escaping (FileType) -> Void,
        start: @escaping (FileType, Bool) -> Void
    ) {
        self.queue = queue
        self.supersede = supersede
        self.start = start
    }

    /// Starts an Apply of `type` after `delay`, replacing any older one of the same type.
    /// - Parameter force: Draw every icon again, also where it is up to date (Regenerate).
    func schedule(_ type: FileType, after delay: TimeInterval, force: Bool = false) {
        cancel(type)
        let item = DispatchWorkItem { [start] in start(type, force) }
        lock.lock()
        timers[type] = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Drops the waiting and the running Apply of `type`.
    func cancel(_ type: FileType) {
        lock.lock()
        timers.removeValue(forKey: type)?.cancel()
        generations[type, default: 0] += 1
        lock.unlock()
        supersede(type)
    }

    /// Changes whenever something newer was scheduled or cancelled for `type`.
    func generation(of type: FileType) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return generations[type, default: 0]
    }

    /// False once a newer Apply of `type` was scheduled after `generation` was read; the old run must stop.
    func isCurrent(_ type: FileType, generation: Int) -> Bool {
        self.generation(of: type) == generation
    }
}
