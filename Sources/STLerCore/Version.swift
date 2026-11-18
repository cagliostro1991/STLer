import Foundation

/// The app's own version. `VERSION` in the repository root has to say the same; a self-check compares them.
enum AppVersion {
    static let current = "0.1.0-beta.2"
}

/// A semantic version with an optional prerelease part: `1.2.3`, `0.1.0-beta.2`. A leading `v` is accepted.
struct SemVer: Comparable, Equatable {
    let numbers: [Int]
    let prerelease: [String]

    init?(_ text: String) {
        var text = text.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("v") { text.removeFirst() }
        let halves = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = halves[0].split(separator: ".", omittingEmptySubsequences: false).map {
            Int($0)
        }
        guard numbers.count == 3, !numbers.contains(nil) else { return nil }
        self.numbers = numbers.compactMap { $0 }
        prerelease = halves.count > 1 ? halves[1].split(separator: ".").map(String.init) : []
    }

    var isPrerelease: Bool { !prerelease.isEmpty }

    /// Numbers first; with equal numbers a release is newer than any prerelease; prerelease identifiers compare one by one,
    /// numerically when both are numbers (`beta.2` < `beta.10`), otherwise as text.
    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        if lhs.prerelease.isEmpty || rhs.prerelease.isEmpty {
            return !lhs.prerelease.isEmpty && rhs.prerelease.isEmpty
        }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            if let x = Int(a), let y = Int(b) { return x < y }
            return a < b
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}
