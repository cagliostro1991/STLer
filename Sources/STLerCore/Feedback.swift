import Foundation

/// Links that open GitHub's issue and discussion forms with the version and macOS already filled in.
enum Feedback {
    private static var base: String { "https://github.com/\(UpdateChecker.repository)" }

    /// A new issue from one of the forms in `.github/ISSUE_TEMPLATE`.
    /// - Parameter template: File name of the form, for example `bug_report.yml`.
    static func issueURL(template: String) -> URL {
        var parts = URLComponents(string: "\(base)/issues/new")!
        parts.queryItems = [
            URLQueryItem(name: "template", value: template),
            URLQueryItem(name: "version", value: AppVersion.current),
            URLQueryItem(
                name: "macos", value: ProcessInfo.processInfo.operatingSystemVersionString),
        ]
        return parts.url!
    }

    /// A new discussion in a category such as `q-a` or `ideas`.
    static func discussionURL(category: String) -> URL {
        var parts = URLComponents(string: "\(base)/discussions/new")!
        parts.queryItems = [URLQueryItem(name: "category", value: category)]
        return parts.url!
    }
}
