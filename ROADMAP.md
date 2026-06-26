# goodmap roadmap

Goal: **the beautiful, open, Flutter-native alternative to Google Maps** — a map
toolkit that is gorgeous by default, works everywhere, and ships a 3D globe no
one else has.

This is a living document. Dates are intentionally omitted; milestones ship when
they're solid. Issues and PRs are welcome on anything here — and on things that
aren't.

## Guiding principles

- **Beautiful by default.** Zero-config components that look great and follow the
  host app's `Theme`.
- **Pure-Dart where it counts.** Projection, tiling, occlusion, clustering and
  registries stay in plain, unit-tested Dart; native/GPU code is quarantined.
- **Additive & predictable.** Each surface is independent; a small, controller-
  based API. No surprises, no breaking changes within a major.
- **Open.** MIT, no mandatory API keys, no vendor lock-in. Bring-your-own tiles,
  routing and geocoding.

## Where we stand (0.1.0)

| Area | Status |
|---|---|
| Flat map (MapLibre): theme-aware basemaps, camera, markers, popups, polylines, controls | ✅ |
| 3D globe (`ui.FragmentProgram`): tiles, arcs, points, labels, atmosphere, tap | ✅ |
| Hybrid globe↔flat handoff (`GoodMapGlobe`) | ✅ |
| Platforms: iOS + Android (flat), iOS/Android/web/desktop (globe) | ✅ |

## Competitive snapshot

| Capability | goodmap today | google_maps_flutter | flutter_map |
|---|---|---|---|
| Beautiful theme-aware default | ✅ | ⚠️ styling needed | ⚠️ DIY |
| **Native 3D globe + arcs** | ✅ **unique** | ❌ | ❌ |
| Markers / popups | ✅ | ✅ | ✅ |
| Polylines | ✅ | ✅ | ✅ |
| Polygons / circles | ⏳ 0.2 | ✅ | ✅ |
| Marker clustering | ⏳ 0.2 | plugin | plugin |
| User location | ⏳ 0.2 | ✅ | plugin |
| Custom tiles / styles | ⏳ 0.2 | ⚠️ | ✅ |
| Heatmaps | ⏳ 0.4 | plugin | plugin |
| Routing / geocoding | ⏳ 0.5 (pluggable) | via Google APIs | plugin |
| No API key required | ✅ | ❌ | ✅ |

Our edge: **the globe + out-of-the-box beauty**. Our gap to close: the everyday
layers (polygons, clustering, location) and pluggable services (routing, search).

---

## 0.2.0 — Real-world map essentials

Close the gap for the apps people actually build.

- **Marker clustering** — pure-Dart grid/distance clustering, animated; works on
  flat map and globe.
- **Polygons & circles** — `addPolygon` / `addCircle` on `GoodMapController`
  (fill + stroke), with hit-testing.
- **User location layer** — opt-in `geolocator` integration: location dot +
  accuracy ring, follow-me camera mode, and a `locate` control.
- **GeoJSON helper** — load points/lines/polygons from GeoJSON in one call.
- **Custom basemaps** — supply a style URL / tile template (flat) and a raster
  tile source (globe); not just CARTO light/dark.
- **Shared overlay vocabulary** — unify flat + globe marker/popup types so code
  moves between surfaces unchanged.

## 0.3.0 — Globe depth & smoothness

Lean into the differentiator.

- **Windowed per-region LOD on the globe** — fetch z11–14 tiles for the visible
  cap into a detail texture; real street detail when you zoom, and it fixes the
  current load-time/memory cost of the whole-world atlas.
- **Smoother handoff** — hold the globe's last frame under the flat map during
  the `GoodMapGlobe` cross-fade (kills the PlatformView pop-in); investigate a
  continuous globe→mercator morph as a stretch.
- **Globe polygons / choropleth** — filled regions and country shading on the
  sphere.
- **Globe clustering** — cluster dense points on the globe with occlusion.
- **Offline / disk tile cache** — cache fetched tiles; faster relaunch, basic
  offline.

## 0.4.0 — Data visualization & richness

- **Heatmaps** — flat map and globe.
- **pointed map** 
- **Custom globe textures & day/night** — satellite imagery, other planets, and
  a day/night terminator (sun position).
- **Animated/time-series data** — points and arcs that animate over a timeline.
- **3D building extrusions** — fill-extrusion layers on the flat map.

## 0.5.0 — Services & platform parity

The "Google Maps" features — pluggable, key-optional.

- **Geocoding & places search** — a provider interface with a default
  open backend (Nominatim/Photon); search box widget.
- **Routing / directions** — a provider interface (OSRM / Valhalla); draw the
  returned route as a polyline with turn list.
- **Web flat-map hardening** — first-class maplibre web support for `GoodMap`.
- **Desktop polish** — gestures, controls, packaging.

## 1.0.0 — Stability, docs, polish

- **API freeze** + full dartdoc + a docs site / cookbook.
- **Golden & integration tests**, CI, performance benchmarks vs alternatives.
- **Accessibility** — semantics for markers/controls.
- **Migration guide** and long-term support commitment.

---

## Ongoing — bug fixes & hardening

Tracked continuously, not tied to a milestone:

- [ ] `GoodMapGlobe` cross-fade pop-in (native `PlatformView` doesn't fade) —
      hold last globe frame during transition. *(0.3 target)*
- [ ] Globe first-paint time & transient memory at tile-zoom 4 — superseded by
      windowed LOD. *(0.3 target)*
- [ ] Tile fetch: retry/backoff, graceful offline, attribution polish.
- [ ] Theme-reload race edge cases (rapid light/dark toggles).
- [ ] Golden-test coverage for globe widgets (projection is unit-tested; pixels
      aren't).
- [ ] Rename the example's Android application id (`dev.mapcn.example`).
- [x] Overlay markers vanishing on Android (device-pixel-ratio) — fixed in 0.1.0.

## Vision / stretch

- **Vector tiles on the globe** — roads/labels re-rendered in 3D. Large effort
  (a vector renderer on a sphere); long-term.
- **Plugin ecosystem** — a layer API so others can add sources/overlays.
- **Live data** — real-time markers, cursors, fleet/flight tracking on the globe.

## How to contribute

Good first issues: polygons/circles, GeoJSON loading, clustering, custom tile
sources. Open an issue to claim something or propose a new direction — the
roadmap is a starting point, not a fence.
