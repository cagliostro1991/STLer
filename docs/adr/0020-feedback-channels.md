# 0020. Where feedback goes: forms, discussions, a wiki with sources in the repo

- Status: accepted
- Date: 2026-11-17

## Context

The repository is public and the first beta is out. People will have questions, bugs, ideas and format wishes, and one free-text issue box mixes them all.

## Decision

- **Issues are for work**: three issue forms (bug report, feature request, file format request) with required fields (version, macOS, steps), blank issues off. `config.yml` sends questions and ideas to Discussions and vulnerabilities to private reporting.
- **Discussions are for talk**: Q&A and Ideas, with their own forms. An idea that becomes concrete work turns into an issue.
- **Security** goes through GitHub private vulnerability reporting (`SECURITY.md`), the Code of Conduct uses the same private channel, so no e-mail address is published.
- **Wiki is the user guide** (getting started, FAQ, troubleshooting, how to give feedback). Its sources live in `docs/wiki/` so changes are reviewed like code; the wiki repository is a copy. Developer docs stay in `docs/` (ADRs, knowledge).
- **The app links to the forms** with version and macOS prefilled (`Feedback`), so a report starts with the facts we always ask for.
- Labels: `needs-triage` on new issues, `needs-info` when we wait for the reporter, `format-request`, plus the GitHub defaults (`bug`, `enhancement`, `good first issue`, `help wanted`, `wontfix`, `duplicate`, `question`).

## Consequences

- The form field ids (`version`, `macos`) are part of the app's links: renaming them breaks the prefill. A self-check keeps the form files present.
- Two copies of the wiki (repo and GitHub) have to be synced by hand, see `docs/wiki/README.md`.
- Response times are promised only as "about a week", it is a spare-time project.
