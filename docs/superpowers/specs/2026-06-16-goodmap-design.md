# goodmap for Flutter — v1 Design

**Date:** 2026-06-16
**Status:** Approved for planning
**Author:** ildysilva
**Project location:** `~/labs/goodmap` (new standalone repo)

## Summary

A Flutter port of [goodmap](https://goodmap.dev) — theme-aware, ready-to-use map
components — distributed as a normal **pub.dev package** built on top of the
`maplibre_gl` plugin. v1 targets a small, solid core: a themed map widget, a
controller for camera and markers, overlay-based popups, and zoom + compass
controls. iOS and Android only.

This is a **new, standalone project** — a separate package, not part of the
existing Next.js docs/registry repo. The original goodmap repo is a React/shadcn
registry; this design borrows its component vocabulary and theme-aware
philosophy, not its distribution model (Flutter uses pub.dev packages, not a
copy-paste registry).

## Goals

- Idiomatic Flutter package usable via `flutter pub add` + `import`.
- Theme-aware: map basemap and component styling follow the host app's
  light/dark `Theme`.
- Mirror goodmap's component vocabulary where it makes sense on native mobile.
- Clean, predictable, controller-based API over `maplibre_gl`.

## Non-Goals (v1)

- Web and desktop platforms (deferred; `maplibre_gl` web support is thinner).
- Data layers: routes, arcs, clusters, heatmaps (later versions).
- Full-page demo blocks (analytics, logistics, delivery-tracker, heatmap).
- A copy-paste / CLI registry distribution model.
- `locate` and `fullscreen` controls.
- Forking or vendoring `maplibre_gl`.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Distribution | pub.dev package | Idiomatic Flutter; easiest adoption. |
| Map engine | `maplibre_gl` | Only option with native vector-tile + GL style-layer parity to goodmap. |
| v1 scope | Core only: Map, Marker, Popup, Controls, theming | Proves the foundation (theming + imperative bridge) before porting everything. |
| Platforms | iOS + Android | `maplibre_gl`'s native sweet spot; no platform caveats in v1. |
| API style | Controller-based (thin wrapper) | `GoodMapController` exposes typed methods; less to build, predictable. |
| Popups | Flutter overlay widgets | The standard, native-quality way; full Flutter widget freedom. No fork. |
| Markers | Overlay widgets by default; optional widget-to-image | Overlay = interactive/stateful; widget-to-image = baked into GL scene (static). |
| Controls | zoom + compass/reset-bearing | Fullscreen is meaningless on mobile; locate needs `geolocator` + permissions (deferred). |

### Why no fork of `maplibre_gl`

The map renders as a **native PlatformView** (native MapLibre SDK draws the GL
scene onto a native texture). Flutter widgets live in the Flutter widget tree
and can only be composited *over/under* the platform view, never *inside* the
GL scene. Therefore no fork can produce a "native rich Flutter-widget popup" —
the boundary is in how Flutter embeds native views, not in `maplibre_gl`.
Forking would only expose native (Swift/Kotlin) callouts, defeating the goal of
rich Dart widgets, at a high maintenance cost. The overlay-projection approach
is the standard native-quality solution used across `google_maps_flutter`,
`mapbox`, and `maplibre_gl`.

## Architecture

Standard pub.dev package layout:

```
goodmap/
├── lib/
│   ├── goodmap.dart                  # public exports
│   └── src/
│       ├── goodmap_map.dart          # GoodMap widget (MapLibreMap + overlay Stack)
│       ├── goodmap_controller.dart   # GoodMapController (wraps MapLibreMapController)
│       ├── theme/
│       │   ├── goodmap_theme.dart     # GoodMapTheme tokens (light/dark)
│       │   └── basemaps.dart        # CARTO positron / dark-matter style URLs
│       ├── markers/
│       │   ├── marker.dart          # MarkerOptions, MarkerId
│       │   └── widget_to_image.dart # optional: snapshot widget → symbol icon
│       ├── popups/
│       │   └── popup_layer.dart      # overlay layer, LatLng→screen projection
│       └── controls/
│           └── controls.dart         # GoodControls (zoom, compass)
├── example/                          # runnable demo app (iOS + Android)
├── pubspec.yaml
└── README.md
```

### Component boundaries

- **`GoodMap`** — `StatefulWidget` rendering a `Stack`:
  1. `MapLibreMap` (native view) at the bottom, with the theme-selected style.
  2. **Popup overlay layer** above it.
  3. **Controls layer** on top.
  On style load it constructs a `GoodMapController` and invokes `onMapReady`.
  Listens to camera changes to drive overlay re-projection.

- **`GoodMapController`** — wraps `MapLibreMapController`. Single point of
  imperative interaction. Owns marker registry and popup registry.

- **`GoodMapTheme`** — pure data: derives marker/popup/control token defaults from
  the host `ColorScheme`; overridable. No widgets.

- **`popup_layer.dart`** — given a list of `(LatLng, Widget)` entries, projects
  each to a screen offset via `controller.toScreenLocation` and positions it in
  the Stack; re-projects on every camera change. The one non-trivial mechanism;
  fully contained here.

## Public API

```dart
GoodMap(
  initialCenter: LatLng(37.77, -122.42),
  initialZoom: 11,
  controls: const GoodControls(zoom: true, compass: true),
  onMapReady: (GoodMapController c) { /* add markers, popups */ },
)
```

`GoodMapController`:

- **Camera:** `flyTo`, `animateTo`, `fitBounds`, `moveTo`
- **Markers:** `addMarker(MarkerOptions) -> MarkerId`, `updateMarker(MarkerId, ...)`,
  `removeMarker(MarkerId)`, `clearMarkers()`
- **Popups:** `showPopup(LatLng, Widget) -> PopupId`, `hidePopup(PopupId)`,
  `clearPopups()`

`MarkerOptions`:
- `LatLng position` (required)
- `Widget? child` — overlay marker widget (default path)
- `MarkerImage? image` — optional widget-to-image / asset symbol (GL-scene path)
- alignment/anchor, `VoidCallback? onTap`

## Theming

`GoodMap` reads `Theme.of(context).brightness` and selects the CARTO **positron**
(light) or **dark-matter** (dark) vector basemap style. `GoodMapTheme` derives
marker color, popup background/border/radius, and control button colors from the
app's `ColorScheme`, all overridable. On host theme toggle, the map re-applies
the matching style and overlay tokens update.

## Error Handling

- **Pre-ready calls:** `GoodMapController` is only handed to `onMapReady` after the
  style loads, so methods cannot be called before the controller exists.
- **Unknown ids:** `updateMarker`/`removeMarker`/`hidePopup` with an unknown id
  are no-ops (no throw) — safe for async UI churn.
- **Projection during gestures:** overlay re-projection is throttled to camera
  update callbacks; off-screen overlays are positioned out of view rather than
  removed, to avoid flicker.
- **Style reload race:** when theme changes mid-session, markers/popups are
  re-applied after the new style finishes loading.

## Testing

- **Unit (no native map):** `GoodMapTheme` token derivation; marker/popup registry
  add/update/remove/clear semantics including unknown-id no-ops; basemap URL
  selection per brightness.
- **Widget:** `GoodMap` builds the Stack with controls; popup overlay positions
  a widget at a mocked screen offset; controls invoke the right controller
  methods. `MapLibreMapController` is mocked — native rendering is out of scope
  for automated tests.
- **Manual / example app:** the `example/` app is the integration surface on real
  iOS + Android devices (markers, popups, camera, theme toggle).

## Open Items for Planning

- Confirm package name on pub.dev (`goodmap` vs `goodmap`); directory is
  `goodmap` regardless.
- Pin `maplibre_gl` version and confirm CARTO basemap terms for the example app.
