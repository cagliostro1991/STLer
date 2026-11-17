# 0001. Custom file icons instead of a Quick Look extension

- Status: accepted
- Date: 2026-11-17

## Context

The goal was isometric Finder thumbnails for STL. macOS has a built-in provider for `public.standard-tesselated-geometry-format` that wins over third-party ones. A `QLThumbnailProvider` extension was built, signed ad-hoc, registered and enabled (`pluginkit` listed it), tried with and without a custom exported UTI: `QLThumbnailGenerator` always returned the system thumbnail and the extension process was never launched.

## Decision

Render the icon ourselves with SceneKit and set it as the file's custom icon with `NSWorkspace.setIcon`.

## Consequences

- Works in Finder immediately and for 3MF too (which has no system provider).
- The icon lives in the resource fork: lost on `cp` without `-X`, zip, some network volumes.
- Must be applied per file, hence `follow`/`run` (ADR 0003) and the signature (ADR 0002).
- `setIcon` bumps the modification date, see ADR 0007.
