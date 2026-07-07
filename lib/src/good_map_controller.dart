// lib/src/good_map_controller.dart
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide CircleOptions;

import 'internal/registry.dart';
import 'lines/circle.dart';
import 'lines/polygon.dart';
import 'lines/polyline.dart';
import 'markers/marker.dart';
import 'popups/popup.dart';

export 'lines/circle.dart' show CircleId, CircleOptions;
export 'lines/polygon.dart' show PolygonId, PolygonOptions;
export 'popups/popup.dart' show PopupId, PopupOptions;
export 'markers/marker.dart' show MarkerId, MarkerImage, MarkerOptions, GlobePoint;
export 'lines/polyline.dart' show PolylineId, PolylineOptions;

/// Single point of imperative interaction with a [GoodMap]. Wraps the native
/// [MapLibreMapController] and owns the marker + popup registries. Notifies
/// listeners (the overlay layer) whenever overlay entries change.
class GoodMapController extends ChangeNotifier {
  GoodMapController(this._native) {
    _markers.addListener(notifyListeners);
    _popups.addListener(notifyListeners);
  }

  final MapLibreMapController _native;
  final Registry<MarkerOptions> _markers = Registry<MarkerOptions>();
  final Registry<PopupOptions> _popups = Registry<PopupOptions>();
  // Polylines live only in the GL scene (not overlay widgets), so this registry
  // is not wired to notifyListeners — it just allocates ids and stores options
  // for re-application after a style reload.
  final Registry<PolylineOptions> _polylines = Registry<PolylineOptions>();

  final Registry<PolygonOptions> _polygons = Registry<PolygonOptions>();
  final Registry<CircleOptions> _circles = Registry<CircleOptions>();

  // --- Camera -------------------------------------------------------------

  /// Animates the camera to [target], optionally setting [zoom].
  Future<void> flyTo(LatLng target, {double? zoom}) async {
    final update = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newLatLngZoom(target, zoom);
    await _native.animateCamera(update);
  }

  /// Animates the camera to a full [position] (target + zoom/bearing/tilt).
  Future<void> animateTo(CameraPosition position) async {
    await _native.animateCamera(CameraUpdate.newCameraPosition(position));
  }

  /// Animates the camera to frame [bounds] with [padding].
  Future<void> fitBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(40),
  }) async {
    await _native.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
    );
  }

  /// Moves the camera to [target] instantly (no animation), optionally [zoom].
  Future<void> moveTo(LatLng target, {double? zoom}) async {
    final update = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newLatLngZoom(target, zoom);
    await _native.moveCamera(update);
  }

  // Maps marker id -> native Symbol for image markers (GL-scene path).
  final Map<int, Symbol> _symbols = <int, Symbol>{};

  // --- Markers ------------------------------------------------------------

  /// Adds a marker and returns its [MarkerId]. Provide a `child` widget for an
  /// interactive overlay marker, or an `image` for a static GL-scene symbol.
  MarkerId addMarker(MarkerOptions options) {
    final int id = _markers.add(options);
    if (options.image != null) {
      _createSymbol(id, options);
    }
    return MarkerId(id);
  }

  /// Replaces the options for an existing marker. Unknown [id] is a no-op.
  void updateMarker(MarkerId id, MarkerOptions options) {
    if (!_markers.items.containsKey(id.value)) return;
    _markers.update(id.value, options);
    if (options.image != null) {
      _createSymbol(id.value, options); // re-create to reflect new position/icon
    }
  }

  /// Removes a marker. Unknown [id] is a no-op.
  void removeMarker(MarkerId id) {
    if (!_markers.items.containsKey(id.value)) return;
    _markers.remove(id.value);
    _disposeSymbol(id.value);
  }

  /// Removes all markers.
  void clearMarkers() {
    for (final symbol in _symbols.values) {
      _native.removeSymbol(symbol);
    }
    _symbols.clear();
    _markers.clear();
  }

  /// Re-creates GL-scene objects (image-marker symbols, polylines, polygons
  /// and circles) on a freshly loaded style (e.g. after a theme change).
  /// Overlay-widget markers and popups need no re-application — they are
  /// Flutter widgets, not part of the GL scene.
  void reapplyGlObjects() {
    _symbols.clear();
    for (final entry in _markers.items.entries) {
      if (entry.value.image != null) {
        _createSymbol(entry.key, entry.value);
      }
    }
    _lines.clear();
    for (final entry in _polylines.items.entries) {
      _createLine(entry.key, entry.value);
    }
    _fills.clear();
    for (final entry in _polygons.items.entries) {
      _createFill(entry.key, entry.value);
    }
    _circleFills.clear();
    for (final entry in _circles.items.entries) {
      _createCircleFill(entry.key, entry.value);
    }
  }

  Future<void> _createSymbol(int id, MarkerOptions options) async {
    final image = options.image!;
    final Uint8List bytes =
        (await rootBundle.load(image.assetName)).buffer.asUint8List();
    await _native.addImage(image.assetName, bytes);
    final Symbol symbol = await _native.addSymbol(
      SymbolOptions(
        geometry: options.position,
        iconImage: image.assetName,
        iconSize: 1,
      ),
    );
    _symbols[id] = symbol;
  }

  void _disposeSymbol(int id) {
    final symbol = _symbols.remove(id);
    if (symbol != null) _native.removeSymbol(symbol);
  }

  // --- Polylines / routes -------------------------------------------------

  // Maps polyline id -> native Line.
  final Map<int, Line> _lines = <int, Line>{};

  /// Draws a polyline (e.g. a route) through [points] as a native GL line.
  PolylineId addPolyline(
    List<LatLng> points, {
    Color color = const Color(0xFF3F51B5),
    double width = 4,
  }) {
    final options =
        PolylineOptions(points: points, color: color, width: width);
    final int id = _polylines.add(options);
    _createLine(id, options);
    return PolylineId(id);
  }

  /// Removes a polyline. Unknown [id] is a no-op.
  void removePolyline(PolylineId id) {
    if (!_polylines.items.containsKey(id.value)) return;
    _polylines.remove(id.value);
    _disposeLine(id.value);
  }

  /// Removes all polylines.
  void clearPolylines() {
    for (final line in _lines.values) {
      _native.removeLine(line);
    }
    _lines.clear();
    _polylines.clear();
  }

  Future<void> _createLine(int id, PolylineOptions options) async {
    final Line line = await _native.addLine(
      LineOptions(
        geometry: options.points,
        lineColor: options.color.toHexStringRGB(),
        lineWidth: options.width,
        lineOpacity: options.color.a,
      ),
    );
    _lines[id] = line;
  }

  void _disposeLine(int id) {
    final line = _lines.remove(id);
    if (line != null) _native.removeLine(line);
  }

  /// Ensures a polygon ring is closed (first point == last point) as required
  /// by the GeoJSON spec. Returns the same list unchanged if already closed.
  List<LatLng> _closeRing(List<LatLng> ring) {
    if (ring.isEmpty) return ring;
    final first = ring.first;
    final last = ring.last;
    if (first.latitude == last.latitude && first.longitude == last.longitude) {
      return ring;
    }
    return [...ring, first];
  }

  // --- Polygons / fills ---------------------------------------------------

  // Maps polygon id -> native Fill.
  final Map<int, Fill> _fills = <int, Fill>{};

  /// Draws a filled polygon on the map. The polygon's [points] form the outer
  /// ring; optional [holes] define cut-out inner rings.
  PolygonId addPolygon(PolygonOptions options) {
    final int id = _polygons.add(options);
    _createFill(id, options);
    return PolygonId(id);
  }

  /// Removes a polygon. Unknown [id] is a no-op.
  void removePolygon(PolygonId id) {
    if (!_polygons.items.containsKey(id.value)) return;
    _polygons.remove(id.value);
    _disposeFill(id.value);
  }

  /// Removes all polygons.
  void clearPolygons() {
    for (final fill in _fills.values) {
      _native.removeFill(fill);
    }
    _fills.clear();
    _polygons.clear();
  }

  Future<void> _createFill(int id, PolygonOptions options) async {
    final geometry = <List<LatLng>>[
      for (final ring in options.rings) _closeRing(ring),
    ];
    final Fill fill = await _native.addFill(
      FillOptions(
        geometry: geometry,
        fillColor: options.color.toHexStringRGB(),
        fillOpacity: options.opacity,
        fillOutlineColor: options.outlineColor?.toHexStringRGB(),
      ),
    );
    _fills[id] = fill;
  }

  void _disposeFill(int id) {
    final fill = _fills.remove(id);
    if (fill != null) _native.removeFill(fill);
  }

  // --- Circles (area) -----------------------------------------------------

  // Maps circle id -> native Fill (circles are approximated as polygons).
  final Map<int, Fill> _circleFills = <int, Fill>{};

  /// Draws a circular area on the map that scales with zoom. The circle is
  /// approximated as a regular polygon of [CircleOptions.segments] vertices
  /// and rendered via the native fill engine.
  CircleId addCircle(CircleOptions options) {
    final int id = _circles.add(options);
    _createCircleFill(id, options);
    return CircleId(id);
  }

  /// Removes a circle. Unknown [id] is a no-op.
  void removeCircle(CircleId id) {
    if (!_circles.items.containsKey(id.value)) return;
    _circles.remove(id.value);
    _disposeCircleFill(id.value);
  }

  /// Removes all circles.
  void clearCircles() {
    for (final fill in _circleFills.values) {
      _native.removeFill(fill);
    }
    _circleFills.clear();
    _circles.clear();
  }

  Future<void> _createCircleFill(int id, CircleOptions options) async {
    final Fill fill = await _native.addFill(
      FillOptions(
        geometry: [_closeRing(options.polygonPoints)],
        fillColor: options.color.toHexStringRGB(),
        fillOpacity: options.opacity,
        fillOutlineColor: options.outlineColor?.toHexStringRGB(),
      ),
    );
    _circleFills[id] = fill;
  }

  void _disposeCircleFill(int id) {
    final fill = _circleFills.remove(id);
    if (fill != null) _native.removeFill(fill);
  }

  // --- Popups -------------------------------------------------------------

  /// Shows [child] anchored at [position] and returns its [PopupId].
  PopupId showPopup(
    LatLng position,
    Widget child, {
    Alignment alignment = Alignment.bottomCenter,
  }) {
    final int id = _popups.add(
      PopupOptions(position: position, child: child, alignment: alignment),
    );
    return PopupId(id);
  }

  /// Hides a popup. Unknown [id] is a no-op.
  void hidePopup(PopupId id) => _popups.remove(id.value);

  /// Removes all popups.
  void clearPopups() => _popups.clear();

  /// All overlay-widget entries (child-markers + popups) to be projected.
  List<OverlayEntryData> get overlayEntries => <OverlayEntryData>[
        for (final entry in _markers.items.entries)
          if (entry.value.child != null || entry.value.image == null)
            OverlayEntryData(
              key: MarkerId(entry.key),
              position: entry.value.position,
              alignment: entry.value.child != null ? entry.value.alignment : Alignment.center,
              onTap: entry.value.onTap,
              child: entry.value.child ??
                  DefaultDotMarker(
                    color: entry.value.color ?? const Color(0xFF4F86F7),
                    radius: entry.value.radius ?? 4,
                    label: entry.value.label,
                  ),
            ),
        for (final entry in _popups.items.entries)
          OverlayEntryData(
            key: PopupId(entry.key),
            position: entry.value.position,
            alignment: entry.value.alignment,
            child: entry.value.child,
          ),
      ];

  @override
  void dispose() {
    _markers.dispose();
    _popups.dispose();
    _polylines.dispose();
    _polygons.dispose();
    _circles.dispose();
    super.dispose();
  }
}

/// A geographically-anchored widget the overlay layer projects onto the screen.
@immutable
class OverlayEntryData {
  const OverlayEntryData({
    required this.key,
    required this.position,
    required this.child,
    required this.alignment,
    this.onTap,
  });
  final Object key;
  final LatLng position;
  final Widget child;
  final Alignment alignment;
  final VoidCallback? onTap;
}

/// A default circular dot marker with optional label used when a marker has no custom widget.
class DefaultDotMarker extends StatelessWidget {
  const DefaultDotMarker({
    required this.color,
    required this.radius,
    this.label,
    super.key,
  });

  final Color color;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );

    if (label == null) return dot;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x8A000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label!,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 2),
        dot,
      ],
    );
  }
}

