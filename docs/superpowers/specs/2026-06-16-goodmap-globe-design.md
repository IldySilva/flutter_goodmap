# GoodGlobe — Native 3D Globe for goodmap — Design

**Date:** 2026-06-16
**Status:** Approved for planning
**Author:** ildysilva
**Project location:** `~/labs/goodmap` (new surface in the existing package)

## Summary

A native, from-scratch 3D **globe** widget (`GoodGlobe`) for the goodmap
package, rendering a real raster-tiled Earth on a sphere on **iOS and Android** —
with theme-aware basemaps, markers, popups, and great-circle **arcs** projected
onto the globe. This is the package's differentiator: a native mobile globe that
neither `maplibre_gl` (native MapLibre has no globe — see
[#3161](https://github.com/maplibre/maplibre-native/issues/3161)) nor Google Maps
Flutter offers today.

The original goodmap.dev gets a globe "for free" via a one-line
`projection={{type:"globe"}}` in **MapLibre GL JS (web)**. That toggle does not
exist in the native iOS/Android engine. So we build our own scoped globe renderer
rather than depend on Mapbox or a web view.

## Goals

- A real, interactive native globe on iOS + Android, owned in-package (no Mapbox,
  no third-party map SDK, no web view).
- Theme-aware (light/dark) raster basemap matching the package's
  positron/dark-matter identity.
- Reuse goodmap's existing vocabulary: same `MarkerOptions`/`PopupOptions`, same
  camera verbs, plus arcs.
- Keep the hard correctness (projection, tiling, occlusion math) in pure Dart so
  it is unit-testable without a GPU.

## Non-Goals (v1)

- Full **vector** tiles on the sphere (roads/labels/fills re-rendered in 3D) —
  that is effectively reimplementing a vector renderer; raster only for v1.
- A continuous globe↔flat **morph** or hybrid handoff to `GoodMap`. v1 is a
  standalone globe that stays a globe at all zooms.
- Deep per-tile street-level LOD (Approach B below) — v2.
- Web/desktop. v1 targets iOS + Android, same as the flat map.
- Replacing `GoodMap` — the globe is an additive sibling surface.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Globe surface | **Raster** map tiles on the sphere | Real-map look, ownable in months; avoids reimplementing vector rendering. |
| Render tech | **`flutter_gpu`** (low-level, Impeller) | Real GPU 3D in Dart, single codebase, headroom for a dense smooth sphere + atmosphere shader. |
| Tile→sphere | **Approach A**: UV sphere + one evolving **equirectangular** atlas | One mesh, one texture, trivial lat/lng UV math shared by tiles and overlays; poles covered. |
| Mercator→equirect | GPU render-to-texture blit with a vertical-remap shader | Web tiles are Mercator; the atlas is equirectangular. Reprojection isolated to one shader. |
| Zoom scope | **Standalone** globe (rotate/zoom/tilt/tap), no flat handoff | One renderer; simplest shippable scope. |
| Overlays | Flutter widgets in an overlay `Stack` (reuse `GoodOverlayLayer` idea) | Crisp, tappable, theme-styled; consistent with the package philosophy. |
| Integration | New `GoodGlobe` widget + `GoodGlobeController`, additive | Can't reuse the native MapLibre PlatformView; mirrors `GoodMap` so devs feel at home. |

## Architecture

`GoodGlobe` is a `StatefulWidget` rendering a `Stack`, mirroring `GoodMap`:

1. **Bottom — GPU globe:** a `flutter_gpu` render of the textured sphere +
   atmosphere, driven by a `Ticker` render loop (renders only when dirty/animating).
2. **Middle — overlay layer:** projects lat/lng → 3D sphere → screen (the globe's
   analog of `toScreenLocation`), positions marker/popup widgets and paints arcs,
   with back-of-globe occlusion.
3. **Top — controls:** reuse `GoodControlsView` (zoom ±, compass/reset-north).

Two internal subsystems with narrow interfaces:

- **`GlobeRenderer`** — owns the GPU: sphere mesh, camera matrices, atmosphere,
  draw loop. **All `flutter_gpu` calls are quarantined here** so experimental-API
  churn touches one file. Interface: "give me the current atlas texture; here is
  the viewProjection."
- **`TileAtlas`** — owns fetch → decode → Mercator→equirect reproject → composite
  raster tiles into the equirectangular texture; exposes "current texture" +
  "mark region dirty for this visible area/zoom."

`GoodGlobeController` mirrors `GoodMapController` and is handed to `onGlobeReady`.

### File structure (additive)

```
lib/src/globe/
  goodmap_globe.dart          # GoodGlobe widget (Stack: renderer + overlay + controls)
  globe_controller.dart     # GoodGlobeController (camera, markers, popups, arcs)
  globe_camera.dart         # GlobeCamera state + viewProjection matrix
  sphere_math.dart          # latLngToUnitSphere, projection, occlusion, great-circle slerp
  globe_renderer.dart       # GlobeRenderer (flutter_gpu: mesh, draw loop, atmosphere) [device]
  sphere_mesh.dart          # UV-sphere vertex/index buffer generation
  tile_atlas.dart           # TileAtlas: cover selection, fetch/decode, dirty tracking
  mercator.dart             # Mercator<->equirect coordinate math, tile-cover selection
  globe_overlay_layer.dart  # projects overlays onto sphere; occlusion; anchors
  arc_layer.dart            # great-circle arc sampling + CustomPainter + occlusion + hit-test
  arc.dart                  # ArcId, ArcOptions
  globe_options.dart        # GlobeOptions (atmosphere, autoSpin, colors), GlobeCamera
```

## Rendering pipeline & projection math

**Coordinate core (one function, reused everywhere).**
`latLngToUnitSphere(LatLng)` → 3D point on unit sphere:
`x = cos(lat)·cos(lng)`, `y = sin(lat)`, `z = cos(lat)·sin(lng)`.
Used for mesh vertices, overlay projection, and arc anchoring — tiles and markers
can never drift out of registration.

**Mesh.** A UV sphere (~96 lat-bands × 192 lng-segments) generated once into a
`flutter_gpu` vertex buffer. Vertex UVs are equirectangular
(`u = lng/360 + 0.5`, `v` from latitude), sampling the `TileAtlas` directly.

**Camera.** `GlobeCamera { centerLatLng, zoom, bearing, tilt }`. `zoom` derives a
camera `distance`. Each frame builds `view × perspective = viewProjection`
(`Matrix4`, `vector_math`). Gestures mutate camera state; an animation tween drives
`flyTo`/`animateTo`.

**Draw loop** (`Ticker`, only when dirty/animating):
1. advance camera animation,
2. if atlas changed, upload the new equirect texture,
3. draw the globe sphere (depth-tested, **unlit** — tiles carry color),
4. draw atmosphere: a slightly larger back-faced sphere with a Fresnel rim-glow
   fragment shader behind the globe,
5. Flutter composites the overlay `Stack` on top.

**Overlay projection (shared math).** Per overlay: `latLngToUnitSphere` ×
`viewProjection` → NDC → screen offset. Visibility = sign of
`dot(pointNormal, cameraForward)`; far-hemisphere points are culled. Pure math,
unit-testable without a GPU.

## Tile pipeline & theming (`TileAtlas`)

**Source.** CARTO raster XYZ — `…/light_all/{z}/{x}/{y}.png` and
`…/dark_all/{z}/{x}/{y}.png`, chosen by `Theme.of(context).brightness` (raster twin
of positron/dark-matter). CARTO + OpenStreetMap attribution renders as a small
corner overlay (legal requirement).

**The atlas.** One equirectangular RGBA texture (~2048×1024 world, configurable),
full lat/lng so poles are covered (Mercator tiles reach ±85°; thin polar caps get
the nearest row stretched — invisible in practice).

**Ingest pipeline**, per visible tile:
1. **Cover** — from camera center + zoom, select XYZ tiles covering the visible
   hemisphere at an appropriate `z`.
2. **Fetch + decode** — HTTP → `ui.Image`, through an in-memory LRU cache (disk
   cache is v2).
3. **Reproject Mercator→equirect** — draw each tile as a quad into the atlas
   render-target with a `flutter_gpu` fragment shader remapping Mercator-y → linear
   latitude.
4. **Mark dirty** — renderer picks up the updated atlas next frame.

**Zoom / LOD (v1).** A single global atlas whose source `z` is picked from camera
distance; zooming refetches the focused region at higher `z`. True per-tile
deep-zoom LOD = v2 (Approach B).

**Theme switch.** On brightness change: swap source, invalidate atlas, refetch —
analog of the flat map's style reload; overlay registries persist.

**Testable seams.** Tile-cover selection and the Mercator→equirect remap are pure
Dart (unit-tested); only the GPU blit needs a device.

## Overlays — markers, popups, arcs

All three live in the Flutter overlay layer above the GPU globe (never baked into
the GPU scene), so they stay crisp, tappable, theme-styled.

**Markers & popups.** Reuse `MarkerOptions`/`PopupOptions`/`MarkerId`/`PopupId`
unchanged. Each frame the layer projects entries via the shared globe projection and
positions widgets with the existing anchor/`FractionalTranslation` logic.
**Occlusion:** an entry on the far hemisphere is removed from the tree (marker
vanishes behind the globe, reappears on the way around). Taps work as today
(front-side markers are real `GestureDetector`s).

**Tap-to-coordinate.** A tap ray-casts from the screen point through the camera into
the unit sphere; first intersection → lat/lng. Powers `onTap(LatLng)` and marker
placement.

**Arcs.** `addArc(LatLng from, LatLng to, {color, width, bend, segments, onTap})`:
1. **slerp** between endpoints' 3D vectors → `segments` great-circle points;
2. **lift** each point by `bend × chordLength` → the curve bowing off the globe;
3. a `CustomPainter` projects those 3D points and strokes a `Path` (AA, theme color,
   optional gradient/animated draw-on);
4. **occlusion per sample** — hide any arc point whose view ray hits the globe before
   reaching it (arcs dipping behind the limb clip correctly).
Hover/tap = hit-test against a widened invisible stroke. Arcs use the same
`Registry`/`ArcId` pattern (`addArc`→`ArcId`, `removeArc`, `clearArcs`).

## Public API

```dart
GoodGlobe(
  initialCenter: LatLng(20, 0),
  initialZoom: 2,
  controls: const GoodControls(zoom: true, compass: true),
  theme: null,                       // null => derived from Theme.of(context)
  options: const GlobeOptions(atmosphere: true, autoSpin: true, autoSpinSpeed: 0.02),
  onTap: (LatLng p) { },
  onGlobeReady: (GoodGlobeController c) { },
)
```

`GoodGlobeController`:

```dart
// Camera
Future<void> flyTo(LatLng target, {double? zoom});
Future<void> animateTo(GlobeCamera camera);
Future<void> moveTo(LatLng target, {double? zoom});
Future<void> resetNorth();
// Markers / popups (reuse existing types verbatim)
MarkerId addMarker(MarkerOptions o);  void updateMarker(MarkerId, MarkerOptions);
void removeMarker(MarkerId);          void clearMarkers();
PopupId showPopup(LatLng, Widget, {Alignment});  void hidePopup(PopupId);  void clearPopups();
// Arcs
ArcId addArc(LatLng from, LatLng to, {Color? color, double width = 2, double bend = 0.3, int segments = 64, VoidCallback? onTap});
void removeArc(ArcId);  void clearArcs();
// Idle spin
void startSpin();  void stopSpin();
```

**New public types:** `GoodGlobe`, `GoodGlobeController`, `GlobeOptions`,
`GlobeCamera`, `ArcId`, `ArcOptions`.
**Reused unchanged:** `MarkerOptions`, `PopupOptions`, `MarkerId`, `PopupId`,
`GoodControls`, `GoodMapTheme`, `LatLng`.
Atmosphere color defaults from `ColorScheme`, overridable in `GlobeOptions`.
Everything is **additive** — the existing flat-map API and package are untouched.
Arcs are globe-first but typed so the flat `GoodMapController` can later gain the same
`addArc` (great-circle polyline) with no rework.

## Error handling

- **Capability gate:** check Impeller/`flutter_gpu` availability on init; if
  unsupported, render `GlobeOptions.fallbackBuilder` (default: a "globe unavailable
  on this device" placeholder) instead of crashing.
- **Tile failures:** skip/retry; last-good atlas stays — a missing tile never blanks
  or crashes the globe.
- **Pre-ready calls:** controller only handed out via `onGlobeReady`.
- **Unknown ids:** `removeMarker`/`removeArc`/`hidePopup` on stale ids are no-ops
  (reuse `Registry` semantics).
- **Theme reload race:** brightness change refetches tiles; registries persist.
- **Dispose:** release GPU buffers/textures, stop the ticker, cancel in-flight fetches.

## Risks

- **`flutter_gpu` is experimental** → API churn. Mitigation: pin the Flutter
  version; quarantine all GPU calls behind `GlobeRenderer`.
- **Impeller required** → non-Vulkan older Android unsupported. Mitigation:
  capability gate + documented minimums; flat `GoodMap` remains universal.
- **Mercator→equirect seams/precision** (MapLibre's own single-pixel-seam warning) —
  contained to the atlas blit shader; tested in isolation.
- **Scope** — multi-week. Hence phasing with a hard go/no-go gate after the spike.

## Testing

- **Unit (no GPU, the bulk):** `latLngToUnitSphere`; camera `viewProjection`;
  overlay projection + occlusion; arc great-circle sampling + occlusion; tile-cover
  selection; Mercator↔equirect remap; registry semantics.
- **Widget:** `GoodGlobe` builds the Stack + controls; overlay positions a marker at
  a mocked projection; arc painter yields the expected `Path` (`PathMetrics`).
  `GlobeRenderer`/`TileAtlas` mocked.
- **Manual/example:** a globe screen (city arcs, markers, theme toggle, auto-spin) on
  real iOS + Android — the integration surface for the GPU path.

## Phased build (one implementation plan per phase)

- **Phase 0 — Spike / go-no-go:** `flutter_gpu` textured UV sphere + orbit camera +
  one static image, on one device. Proves the GPU path before further investment.
- **Phase 1 — TileAtlas:** cover selection, fetch/decode, Mercator→equirect
  reprojection + composite, light/dark, distance-based LOD.
- **Phase 2 — Overlays:** markers/popups projection + occlusion + tap, controls,
  `GoodGlobeController`.
- **Phase 3 — Arcs:** great-circle sampling + occlusion + hover/tap.
- **Phase 4 — Polish:** atmosphere shader, auto-spin, attribution, example app screen.

We only commit to Phases 1–4 after the Phase 0 spike proves out.

## Open Items for Planning

- Confirm minimum Flutter SDK that ships a usable `flutter_gpu` API; pin it.
- Confirm CARTO raster basemap terms for production use (attribution included).
- Decide atlas base resolution and re-window strategy threshold for zoom-in detail.
