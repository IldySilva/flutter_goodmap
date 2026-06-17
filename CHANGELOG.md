# Changelog

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
