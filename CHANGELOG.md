# Changelog

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
