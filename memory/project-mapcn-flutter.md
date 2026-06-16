---
name: project-mapcn-flutter
description: mapcn Flutter port — goal and locked v1 design decisions
metadata:
  type: project
---

Porting [mapcn](https://mapcn.dev) (React/shadcn map components) to Flutter as a
standalone project at `~/labs/mapcn_flutter`. Borrows mapcn's component
vocabulary and theme-aware philosophy, NOT its copy-paste registry distribution.

Locked v1 decisions (2026-06-16):
- Distribution: normal **pub.dev package** (not a copy-paste registry).
- Map engine: **`maplibre_gl`** (native vector-tile / GL style-layer parity).
- Scope: **core only** — Map, Marker, Popup, Controls, theme-aware light/dark.
- Platforms: **iOS + Android only** (web/desktop deferred).
- API style: **controller-based** thin wrapper (`MapcnController` with typed methods).
- Popups: **Flutter overlay widgets**; markers: overlay default + optional widget-to-image.
- Controls: **zoom + compass** only (no fullscreen; locate deferred — needs geolocator).
- **No fork of `maplibre_gl`** — map is a native PlatformView, so Flutter widgets
  can never render inside the GL scene; overlay-projection is the native-quality answer.

Design spec: `docs/superpowers/specs/2026-06-16-mapcn-flutter-design.md`.
