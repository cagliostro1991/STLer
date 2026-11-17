# Feedback and requests

Pick the place that fits. All of them are public except security reports.

| I want to... | Use | What happens next |
|---|---|---|
| ask "how do I..." | [Discussions, Q&A](https://github.com/cagliostro1991/STLer/discussions/new?category=q-a) | Other users or the maintainer answer. Mark the helpful answer. |
| suggest something, show my setup | [Discussions, Ideas](https://github.com/cagliostro1991/STLer/discussions/new?category=ideas) | We talk it through. If it becomes concrete work it turns into an issue. |
| report a bug | [Bug report](https://github.com/cagliostro1991/STLer/issues/new?template=bug_report.yml) | Labelled and triaged. We may ask for more details (label `needs-info`). |
| ask for a feature | [Feature request](https://github.com/cagliostro1991/STLer/issues/new?template=feature_request.yml) | Discussed in the issue, accepted ones get a milestone or the `help wanted` label. |
| ask for a file format | [Format request](https://github.com/cagliostro1991/STLer/issues/new?template=format_request.yml) | Rated on the traffic-light list (green planned, yellow maybe, red unlikely) with the reason. |
| report a vulnerability | [Private report](https://github.com/cagliostro1991/STLer/security/advisories/new) | Only the maintainer sees it. Please no public issue. |

In the app, **General > About** has "Report a problem" and "Ask or suggest" buttons that open these forms with your STLer and macOS versions already filled in.

## How to write a report that gets fixed

1. One problem per report.
2. The version (`stler version`) and macOS version.
3. What you did, what you saw, what you expected.
4. For a wrong-looking icon: a small model that shows it (only if you may share it) and the settings (`stler config get`).
5. The journal line or the end of `~/Library/Logs/stler.log`, with private paths removed.
6. A screenshot of the window, not of the whole screen.

## What replies to expect

- A first reply within about a week. This is a spare-time project, a gentle ping after two weeks is fine.
- A request can be declined (`wontfix`) with a reason, for example a closed file format. That is about the request, not about you.
- Duplicates are closed with a link to the original: please add your details or a thumbs up there.
- After a fix, the issue closes with the version that has it. Reopen it if the problem remains.

## Contributing code

See [CONTRIBUTING.md](https://github.com/cagliostro1991/STLer/blob/main/CONTRIBUTING.md). Small fixes: open a pull request. Bigger changes: talk first in an issue or a discussion.
