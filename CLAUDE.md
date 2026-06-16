# goodmap

Cool, beautiful, ready-to-use map components for Flutter — inspired by
[mapcn](https://mapcn.dev), built for native mobile.

## Philosophy

- **Beautiful by default.** Theme-aware components that look good with zero
  configuration and follow the host app's light/dark `Theme`.
- **Ready to use.** Drop-in widgets with a small, predictable, controller-based
  API — not a low-level mapping toolkit.
- **Idiomatic Flutter.** Distributed as a normal pub.dev package; overlays are
  real Flutter widgets, not native callouts.
- **Pure Dart where it counts.** All the hard correctness (projection, tiling,
  occlusion, registries) lives in plain, unit-tested Dart. Native/GPU code is
  quarantined behind narrow interfaces.
- **Additive.** Each surface is independent; adding one never disturbs another.

## Two surfaces

### 1. Flat map (`MapcnMap`)
A themed slippy map built on `maplibre_gl` (native MapLibre, iOS + Android).
- Theme-aware CARTO basemaps (positron / dark-matter) selected by brightness.
- `MapcnController`: camera (`flyTo`/`animateTo`/`fitBounds`/`moveTo`), markers
  (overlay widgets + asset GL symbols), popups, polylines.
- Markers/popups are Flutter widgets projected over the native view via
  `toScreenLocation`; controls (zoom, compass) on top.

### 2. Globe (`MapcnGlobe`)
A native 3D globe with **no `flutter_gpu`** — an orthographic textured sphere
rendered in a single `ui.FragmentProgram` (`shaders/sphere.frag`), drawn via
`CustomPaint`. Works on iOS, Android, web and desktop.
- **Texture:** CARTO raster tiles fetched and reprojected Mercator→equirectangular
  into a `ui.Image` in a background **isolate** (never janks a frame); theme-aware.
- **Interaction:** inertial drag-rotate + pinch-zoom; `unproject` for tap→lat/lng.
- **Overlays:** `GlobePoint` (dot + label) and `GlobeArc` (great-circle, bowed,
  **animated marching dashes**), projected by `SphereProjection` with
  back-of-globe **occlusion**; tap a point for a popup card.
- **Polish:** opt-in atmosphere glow (`atmosphere: true`), off by default.

## Architecture principles

- `SphereProjection` / `sphere.frag` share one rotation convention — overlays and
  texture stay in registration.
- The flat map and the globe are separate widgets; they share value types
  (`MarkerOptions`, `PopupOptions`, `LatLng`) and vocabulary.
- Theme changes re-apply: the flat map reloads its style, the globe rebuilds its
  atlas; overlay registries survive.

## Tech stack

- Flutter ≥ 3.22, Dart ≥ 3.7
- `maplibre_gl` ^0.26.1 (flat map), `vector_math`
- `ui.FragmentProgram` for the globe (stable Flutter shaders — not flutter_gpu)
- Public entry: `import 'package:goodmap/goodmap.dart';`

## Conventions

- Every public surface ships analyze-clean with passing `flutter test`.
- Hard correctness is unit-tested in pure Dart; GPU/native paths are verified in
  the `example/` app on device.
- **Commits in this repo omit the `Co-Authored-By` trailer.**
- `docs/superpowers/plans/`, `MEMORY.md` and `memory/` are internal and untracked.
