# AGENTS.md

Guide for AI agents and contributors working on **goodmap** — cool, beautiful,
ready-to-use map components for Flutter, inspired by [mapcn](https://mapcn.dev).

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

### 1. Flat map (`GoodMap`)
A themed slippy map built on `maplibre_gl` (native MapLibre, iOS + Android).
- Theme-aware CARTO basemaps (positron / dark-matter) selected by brightness.
- `GoodMapController`: camera (`flyTo`/`animateTo`/`fitBounds`/`moveTo`), markers
  (overlay widgets + asset GL symbols), popups, polylines.
- Markers/popups are Flutter widgets projected over the native view via
  `toScreenLocation`; controls (zoom, compass) on top.

### 2. Globe (`GoodGlobe`)
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

### Hybrid (`GoodMapGlobe`)
A globe that cross-fades to the native flat map for street detail past a zoom
threshold, and back. Shares the centre coordinate across surfaces.

## Tech stack

- Flutter ≥ 3.22, Dart ≥ 3.7
- `maplibre_gl` ^0.26.1 (flat map)
- `ui.FragmentProgram` for the globe (stable Flutter shaders — **not** flutter_gpu)
- Public entry: `import 'package:goodmap/goodmap.dart';`

## Commands

```bash
flutter analyze                 # must be clean before committing
flutter test                    # pure-Dart + widget tests (no device needed)
cd example && flutter run       # the demo app — Flat/Globe segmented switch
flutter pub publish --dry-run   # publish readiness (expect 0 warnings)
```

Definition of done for any change: **`flutter analyze` clean and `flutter test`
green.** GPU/native behavior (globe rendering, the native flat map) can't run in
headless tests — verify those in the `example/` app on a device.

## Project layout

```
lib/goodmap.dart                 # public exports (the API surface)
lib/src/
  good_map.dart                  # GoodMap (flat map widget, MapLibre PlatformView)
  good_map_controller.dart       # GoodMapController (camera/markers/popups/polylines)
  controls/controls.dart         # GoodControls + GoodControlsView (zoom/compass)
  markers/ popups/ lines/         # value types (MarkerOptions, PopupOptions, ...)
  popups/popup_layer.dart        # GoodOverlayLayer — projects overlays via toScreenLocation
  internal/registry.dart         # generic id-keyed Registry<T>
  theme/                         # basemaps.dart (CARTO URLs), good_map_theme.dart
  globe/
    good_globe.dart              # GoodGlobe (FragmentProgram sphere widget)
    good_map_globe.dart          # GoodMapGlobe (globe<->flat cross-fade handoff)
    sphere_projection.dart       # orthographic project/unproject (overlays + tap)
    sphere_shader_painter.dart   # FragmentProgram loader + CustomPainter
    tile_atlas.dart              # CARTO tiles -> equirect ui.Image (isolate reproject)
    mercator.dart                # tile/coordinate math
    globe_overlays.dart          # GlobePoint, GlobeArc, painters
shaders/sphere.frag              # the globe shader (flutter: shaders:)
```

## Conventions

- **Commits omit the `Co-Authored-By` trailer.** (Project preference.)
- Every change ships **analyze-clean with passing `flutter test`**.
- Match the surrounding code's style, comment density, and idiom.
- **TDD the pure-Dart cores** (projection, mercator, registries, theming); GPU and
  native paths are verified in `example/` on device, not unit tests.
- Widget tests mock the native `MapLibreMapController` with `mocktail` (see
  `test/helpers/mock_native_controller.dart`); `GoodGlobe` has a
  `@visibleForTesting renderEnabled` flag to skip the GPU path in tests.
- Theme changes re-apply: the flat map reloads its style, the globe rebuilds its
  atlas; overlay registries survive.
- `docs/`, `MEMORY.md`, `memory/` are **internal and git-ignored** — don't rely on
  them being present or commit them.

## Gotchas (read before touching these)

- **The globe uses `ui.FragmentProgram`, NOT `flutter_gpu`.** This was a
  deliberate pivot (stable API, all platforms, no Impeller/shader-bundle gate).
  Do not reintroduce `flutter_gpu`.
- **`shaders/sphere.frag` and `SphereProjection` share one rotation convention.**
  The shader's inverse rotation must mirror `SphereProjection._applyInverseRotation`
  exactly, or overlays drift off the texture. Change them together.
- **`toScreenLocation` is physical pixels on Android, logical on iOS.** Overlay
  placement divides by `devicePixelRatio` on Android (see `popup_layer.dart`). If
  you add new screen-projection code, do the same.
- **Heavy CPU work goes in an isolate.** The tile Mercator→equirect reprojection
  runs via `compute` in `tile_atlas.dart`; keep per-frame/main-thread work light.
- The flat map and globe are **separate widgets** that share value types
  (`MarkerOptions`, `PopupOptions`, `LatLng`). Keep that vocabulary aligned.

## Scope & roadmap

v1 deliberately defers vector-tiles-on-sphere and continuous globe↔flat morph.
See [`ROADMAP.md`](ROADMAP.md) for what's planned and what's intentionally out.
