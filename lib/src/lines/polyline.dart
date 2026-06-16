import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [MapcnController.addPolyline].
@immutable
class PolylineId {
  const PolylineId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is PolylineId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Describes a polyline / route drawn into the GL scene as a native line.
@immutable
class PolylineOptions {
  const PolylineOptions({
    required this.points,
    this.color = const Color(0xFF3F51B5),
    this.width = 4,
  });

  final List<LatLng> points;
  final Color color;
  final double width;
}
