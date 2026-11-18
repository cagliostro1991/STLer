import Foundation

/// Looks for a newer release of STLer on GitHub. Only asks GitHub for the public release list and sends nothing about the user.
enum UpdateChecker {
    /// `owner/name` of the repository whose releases are checked.
    static let repository = "cagliostro1991/STLer"

    struct Release: Equatable {
        let tag: String
        let version: SemVer
        let url: URL
        let prerelease: Bool
    }

    enum Outcome: Equatable {
        case upToDate
        case available(Release)
        case failed(String)
    }

    /// The newest published release in GitHub's `releases` JSON; drafts and tags that are not versions are skipped.
    static func newest(in json: Data) -> Release? {
        guard let list = try? JSONSerialization.jsonObject(with: json) as? [[String: Any]] else {
            return nil
        }
        return list.compactMap { item -> Release? in
            guard item["draft"] as? Bool != true, let tag = item["tag_name"] as? String,
                let version = SemVer(tag),
                let page = (item["html_url"] as? String).flatMap(URL.init(string:))
            else { return nil }
            return Release(
                tag: tag, version: version, url: page,
                prerelease: item["prerelease"] as? Bool ?? version.isPrerelease)
        }.max { $0.version < $1.version }
    }

    /// Decides from a release list whether `current` is outdated. A stable build ignores prereleases, a beta build does not.
    static func outcome(for json: Data, current: String) -> Outcome {
        guard let current = SemVer(current) else {
            return .failed("This build has no valid version number")
        }
        let candidates = (try? JSONSerialization.jsonObject(with: json) as? [[String: Any]]) ?? []
        let usable = candidates.filter { current.isPrerelease || $0["prerelease"] as? Bool != true }
        guard let data = try? JSONSerialization.data(withJSONObject: usable),
            let release = newest(in: data)
        else { return .upToDate }
        return release.version > current ? .available(release) : .upToDate
    }

    /// Asks GitHub and calls back on the main queue. A repository that is private or has no release gives a plain message, not a crash.
    static func check(current: String = AppVersion.current, completion: @escaping (Outcome) -> Void)
    {
        guard
            let url = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=20")
        else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("STLer/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let outcome: Outcome
            if let error {
                outcome = .failed("Could not reach GitHub: \(error.localizedDescription)")
            } else if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
                outcome = .failed(
                    status == 404
                        ? "No public releases found yet." : "GitHub answered with status \(status)."
                )
            } else {
                outcome = Self.outcome(for: data ?? Data(), current: current)
            }
            DispatchQueue.main.async { completion(outcome) }
        }.resume()
    }
}
