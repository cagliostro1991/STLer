# 0015. Apply and Clear are queued jobs, with a journal shared with `follow`

- Status: accepted
- Date: 2026-11-17

## Context

Apply and Clear blocked the window until they finished, and there was no way to see what `stler follow` (a separate LaunchAgent process) was doing.

## Decision

`JobQueue` (Core) runs jobs one at a time on a background queue. A click only adds a job, so the buttons never lock and a second Apply (say another file type) is queued behind the first. Order matters, because Apply then Clear of the same type must not run in parallel.

The journal is one stream, oldest at the top: the last 10 finished jobs, the running one (highlighted, with progress and the file in work), then the queued ones. `stler follow` writes its folder runs to `~/Library/Logs/STLer/activity.json` (`ActivityLog`, `flock`, last 10 finished entries, `STLER_LOG` overrides the path). The window polls that file once a second and merges it into the same stream.

## Consequences

- Follow entries are written only when a folder had files to look at, and progress is written at most once a second.
- Finished window jobs live in memory only; they are gone after a restart. Follow entries survive in the file.
- Live per-file progress of the follow process has a one-second granularity at best.
