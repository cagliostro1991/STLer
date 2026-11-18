import Foundation

/// One Clear or Apply in the journal.
struct Job: Identifiable, Equatable {
    enum State { case queued, running, done }

    var id = UUID()
    let title: String
    var state = State.queued
    var done = 0
    var total = 0
    /// File being handled right now while the job runs.
    var current = ""
    var summary = ""
    var finishedAt = Date.distantPast
}

/// Runs jobs one at a time in the background and remembers the last finished ones.
/// `jobs` reads top to bottom as a stream: finished, the running one, then the queued ones.
final class JobQueue {
    static let keepFinished = 10

    /// What a job's work closure uses to report while it runs.
    struct Reporter {
        let progress: (_ done: Int, _ total: Int, _ file: String) -> Void
        /// True once the user cancelled this job; the work should stop at the next file.
        let isCancelled: () -> Bool
    }

    /// Called after every change, from the worker thread or from the thread that enqueues; it may run concurrently.
    var didChange: (() -> Void)?

    private let lock = NSLock()
    private var items: [Job] = []
    private let worker = DispatchQueue(label: "stler.jobs", qos: .userInitiated)
    private let group = DispatchGroup()
    private var cancelled = Set<UUID>()

    var jobs: [Job] {
        lock.lock(); defer { lock.unlock() }
        return items
    }

    /// Adds a job at the end of the queue.
    /// - Parameter work: Runs on the worker thread; its return value becomes the job's summary.
    /// - Returns: The job's id, for `cancel`.
    @discardableResult
    func enqueue(_ title: String, work: @escaping (Reporter) -> String) -> UUID {
        let job = Job(title: title)
        change { $0.append(job) }
        group.enter()
        worker.async {
            guard self.jobs.contains(where: { $0.id == job.id }) else { self.group.leave(); return }
            self.update(job.id) { $0.state = .running }
            let summary = work(Reporter(progress: { done, total, file in
                self.update(job.id) { $0.done = done; $0.total = total; $0.current = file }
            }, isCancelled: {
                self.lock.lock(); defer { self.lock.unlock() }
                return self.cancelled.contains(job.id)
            }))
            self.update(job.id) { $0.state = .done; $0.summary = summary; $0.current = ""; $0.finishedAt = Date() }
            self.change { items in
                let finished = items.indices.filter { items[$0].state == .done }
                for index in finished.dropLast(Self.keepFinished).reversed() { items.remove(at: index) }
            }
            self.group.leave()
        }
        return job.id
    }

    /// Cancels one job: a waiting one is dropped and never runs, a running one is asked to stop at its next file.
    func cancel(_ id: UUID) {
        lock.lock()
        cancelled.insert(id)
        lock.unlock()
        change { $0.removeAll { $0.id == id && $0.state == .queued } }
    }

    /// Removes the finished jobs and cancels the ones still waiting; the running job is left alone.
    func clear() { change { $0.removeAll { $0.state != .running } } }

    /// Blocks until nothing is queued or running. For tests.
    func waitUntilIdle() { group.wait() }

    private func update(_ id: UUID, _ edit: (inout Job) -> Void) {
        change { items in
            if let index = items.firstIndex(where: { $0.id == id }) { edit(&items[index]) }
        }
    }

    private func change(_ edit: (inout [Job]) -> Void) {
        lock.lock()
        edit(&items)
        lock.unlock()
        didChange?()
    }
}
