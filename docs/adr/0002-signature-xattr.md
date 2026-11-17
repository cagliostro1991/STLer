# 0002. Signature xattr for skip and reset

- Status: accepted
- Date: 2026-11-17

## Context

Reruns must not re-render unchanged files, changing colour/view/badge must re-render only what is stale, and `reset` must never remove icons the user set by hand (a custom icon looks the same whether it is ours or not).

## Decision

Write `dev.stler.sig` (`v3|view|colour|firstPlateOnly|badge`) as an extended attribute on every file we touch. Same signature: skip. Different: re-render. No signature: not ours, never reset.

## Consequences

- No separate database; the marker travels with the file and vanishes with the icon.
- Icons written by a pre-signature build are "foreign" until re-rendered once with `force`.
- Any setting that changes the picture must be in `Signature.make`; bump the prefix when renderer output changes.
