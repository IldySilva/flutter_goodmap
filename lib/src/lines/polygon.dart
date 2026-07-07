import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [GoodMapController.addPolygon].
@immutable
class PolygonId {
  const PolygonId(this.value);
  final int value;

  @override
  bool operator ==(Object other) => other is PolygonId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Describes a polygon drawn into the GL scene as a native fill.
///
/// The [points] list defines the outer ring of the polygon (must be closed —
/// the last point should equal the first for a fully closed shape, though
/// MapLibre will close it automatically). Optional [holes] define inner rings
/// (e.g. a donut shape), where each inner ring is a list of [LatLng].
@immutable
class PolygonOptions {
  const PolygonOptions({
    required this.points,
    this.holes,
    this.color = const Color(0xFF4CAF50),
    this.opacity = 0.5,
    this.outlineColor,
  });

  /// Outer ring of the polygon (minimum 3 points).
  final List<LatLng> points;

  /// Optional inner rings (holes). Each entry is a list of points forming a
  /// ring fully inside the outer ring.
  final List<List<LatLng>>? holes;

  /// Fill colour of the polygon.
  final Color color;

  /// Fill opacity (0.0 – 1.0).
  final double opacity;

  /// Outline colour. When null, no separate outline is drawn (MapLibre
  /// defaults to the fill colour at full opacity).
  final Color? outlineColor;

  /// All rings combined: first the outer ring, then any holes.
  /// Used internally to build the native [FillOptions.geometry].
  List<List<LatLng>> get rings => [points, if (holes != null) ...holes!];
}
