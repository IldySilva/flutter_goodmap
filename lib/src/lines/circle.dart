import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [GoodMapController.addCircle].
@immutable
class CircleId {
  const CircleId(this.value);
  final int value;

  @override
  bool operator ==(Object other) => other is CircleId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Describes a circular area drawn on the map that **scales with zoom**.
///
/// Internally the circle is approximated as a regular polygon with
/// [segments] vertices, rendered via the native fill engine
/// ([FillOptions]). This means the circle behaves like a real geographic
/// area — it grows/shrinks as the user zooms in/out.
///
/// Use [radiusMeters] to specify the geographic radius. For a
/// screen‑pixel circle that stays a fixed size (e.g. a marker dot), use
/// [MarkerOptions] with a custom widget instead.
@immutable
class CircleOptions {
  const CircleOptions({
    required this.center,
    required this.radiusMeters,
    this.color = const Color(0xFF4F86F7),
    this.opacity = 0.3,
    this.outlineColor,
    this.segments = 64,
  });

  /// Centre of the circle.
  final LatLng center;

  /// Geographic radius in metres.
  final double radiusMeters;

  /// Fill colour of the circle.
  final Color color;

  /// Fill opacity (0.0 – 1.0).
  final double opacity;

  /// Outline colour. When null, no separate outline is drawn.
  final Color? outlineColor;

  /// Number of vertices used to approximate the circle (more = smoother).
  final int segments;

  /// Earth mean radius in metres (WGS-84).
  static const double _earthRadius = 6_371_000;

  /// Computes the vertices of a regular polygon that approximates a
  /// geographic circle of [radiusMeters] around [center].
  ///
  /// The returned list is **closed** (first point repeated at the end) so it
  /// can be used directly as a fill geometry ring.
  static List<LatLng> buildCirclePoints(
    LatLng center,
    double radiusMeters, {
    int segments = 64,
  }) {
    final latRad = center.latitude * math.pi / 180;
    final lonRad = center.longitude * math.pi / 180;
    final d = radiusMeters / _earthRadius;

    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final bearing = 2 * math.pi * i / segments;
      final lat = math.asin(
        math.sin(latRad) * math.cos(d) +
            math.cos(latRad) * math.sin(d) * math.cos(bearing),
      );
      final lon =
          lonRad +
          math.atan2(
            math.sin(bearing) * math.sin(d) * math.cos(latRad),
            math.cos(d) - math.sin(latRad) * math.sin(lat),
          );
      points.add(LatLng(lat * 180 / math.pi, lon * 180 / math.pi));
    }
    return points;
  }

  /// Pre-computed polygon ring for this circle. Convenience accessor that
  /// delegates to [buildCirclePoints].
  List<LatLng> get polygonPoints =>
      buildCirclePoints(center, radiusMeters, segments: segments);
}
