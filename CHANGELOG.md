# Changelog

## 0.4.0

Data visualization & richness.

### Dotted World Map ("pointed map")
- **`GoodGlobe.showDottedGrid`** — draws a stylized dotted landmass grid (1,710 pre-computed points from a diagonal dot-map grid) on the globe canvas using `GlobeOverlayPainter`. Configurable dot colour (`dottedGridColor`) and radius (`dottedGridRadius`).
- **`GoodMapGlobe.showDottedGrid`** — threads the same props through the hybrid globe→flat widget.
- **`world_land_dots.dart`** — internal file with the pre-compiled `kWorldLandDots` constant; generated with `dotted-map` (height: 45, diagonal grid).

### Heatmaps
- **`GoodMapController.addHeatmap(HeatmapOptions)`** — adds a heatmap layer backed by a native MapLibre `heatmap` paint layer on a generated GeoJSON source. Returns a `HeatmapId`.
- **`updateHeatmap`**, **`removeHeatmap`**, **`clearHeatmaps`** — full lifecycle management.
- **`HeatmapOptions`** — points, per-point weights, radius, intensity, opacity, and custom gradient ramp.
- **`HeatmapId`** — opaque typed handle.

### 3D Building Extrusions (flat map)
- **`GoodMapController.enableBuildings3D()`** / **`disableBuildings3D()`** — inserts a native `fill-extrusion` layer on the `building` source layer using height/min_height fields from the active basemap, re-applied automatically after theme changes.

### Polygons & Circles (flat map)
- **`GoodMapController.addPolygon(PolygonOptions)`** — draws a filled polygon on the map with outer rings and optional inner rings (holes) using native fills. Returns a `PolygonId`.
- **`GoodMapController.addCircle(CircleOptions)`** — draws a circular area scaling with zoom (approximated as a regular polygon with geodesic calculations). Returns a `CircleId`.
- **`removePolygon`**, **`clearPolygons`**, **`removeCircle`**, **`clearCircles`** — full lifecycle management for polygon and circle layers.

## 0.3.0


Windowed Per-Region Level of Detail (LOD) on the 3D globe.

### 3D Globe
- **Windowed LOD System**: Added dynamic viewport-bound calculation and tile fetching (up to z12 city level) only for the visible portion of the globe when zoom > 3.0.
- **Background Reprojection**: Compiled tiles into local mosaics reprojected Mercator→equirectangular in a background isolate (`compute`) to eliminate main thread jank.
- **Atmosphere Shader Integration**: Upgraded the sphere fragment shader (`shaders/sphere.frag`) and painter (`SphereShaderPainter`) to overlay dynamic high-resolution detail textures seamlessly with meridian-wrapping calculations.
- **Lifecycle & Gestures Throttling**: Added a 250ms debounce for loading high-res details when the camera remains stationary, resetting builder tasks during active dragging, pinch-zooms, and inertial scrolling to maintain smooth 60fps interaction.

## 0.2.0

Shared overlay vocabulary unifying flat map and globe marker/popup types.

### Overlays
- **Shared overlay vocabulary**: Unified `MarkerOptions` and `PopupOptions` across `GoodMap`, `GoodGlobe`, and `GoodMapGlobe` to enable seamless transition and reuse of overlays.
- Deprecated `GlobePoint` in favor of `MarkerOptions` while keeping a backwards-compatible `GlobePoint` subclass.
- Added support for declarative `markers` and `popups` list parameters directly to `GoodMap` and `GoodMapGlobe` constructors, which synchronize dynamically with the underlying `GoodMapController`.
- Project and render interactive custom widget and image asset markers on the 3D globe stack.
- Retained custom high-performance canvas path for simple dot markers on the globe.

## 0.1.0

Initial release. Two map surfaces, inspired by mapcn.

### Flat map — `GoodMap`
- Theme-aware CARTO basemaps (positron / dark-matter) by `Theme` brightness.
- `GoodMapController`: camera (`flyTo` / `animateTo` / `fitBounds` / `moveTo`),
  overlay-widget and asset GL-symbol markers, overlay popups, and polylines /
  great-circle routes.
- Zoom + compass controls; `GoodMapTheme` tokens derived from the `ColorScheme`.

### Globe — `GoodGlobe`
- Native 3D globe rendered with a single `ui.FragmentProgram` orthographic sphere
  shader (no `flutter_gpu`); works on iOS, Android, web and desktop.
- Theme-aware CARTO raster basemap reprojected Mercator→equirectangular in a
  background isolate.
- Inertial drag-rotate, pinch-zoom, and `onTap` → lat/lng.
- `GlobePoint` (dot + label) and `GlobeArc` (great-circle, bowed, animated
  marching dashes) with back-of-globe occlusion; tap a point for a popup.
- Opt-in atmosphere glow (`atmosphere: true`).

### Hybrid — `GoodMapGlobe`
- A globe that becomes a street map: shows `GoodGlobe` at world/regional zoom,
  then cross-fades to the native `GoodMap` (full vector streets/cities) past a
  zoom threshold, and back. The centre coordinate carries across.
