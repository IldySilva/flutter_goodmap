import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Offset;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Orthographic sphere projection matching the `sphere.frag` shader.
///
/// The globe is drawn orthographically: the camera looks down +X at infinity,
/// the sphere is rotated by [rotationX] (latitude) and [rotationZ] (longitude),
/// a point is visible when it lands on the near hemisphere (x > 0), and screen
/// position is `center + (y, -z)` scaled by [radius].
///
/// This mirrors flutter_earth_globe's `getSpherePosition3D` so overlay markers
/// and the rendered texture stay in registration.
class SphereProjection {
  const SphereProjection({
    required this.center,
    required this.radius,
    required this.rotationX,
    required this.rotationZ,
  });

  /// Screen-space centre of the globe.
  final Offset center;

  /// Globe radius in pixels.
  final double radius;

  /// Latitude rotation (radians) — the latitude facing the viewer.
  final double rotationX;

  /// Longitude rotation (radians) — the longitude facing the viewer.
  final double rotationZ;

  /// Projects [coords] to a screen position. Returns null when the point is on
  /// the far hemisphere (occluded by the globe body).
  Offset? project(LatLng coords) {
    final p = _rotated(coords);
    if (p[0] <= 0) return null; // behind the globe
    return Offset(center.dx + p[1], center.dy - p[2]);
  }

  /// Whether [coords] is on the visible (near) hemisphere.
  bool isVisible(LatLng coords) => _rotated(coords)[0] > 0;

  /// Inverse: a screen [point] -> the [LatLng] under it, or null if the point is
  /// outside the globe disc.
  LatLng? unproject(Offset point) {
    final y = point.dx - center.dx;
    final z = -(point.dy - center.dy);
    final distSq = y * y + z * z;
    if (distSq > radius * radius) return null;
    final x = math.sqrt(radius * radius - distSq);
    // Undo rotation: rotateZ(+rotZ) then rotateY(+rotX) on (x,y,z).
    final v = _applyInverseRotation(x, y, z);
    final lat = math.asin((v[2] / radius).clamp(-1.0, 1.0));
    final lon = math.atan2(v[1], v[0]);
    return LatLng(lat * 180.0 / math.pi, lon * 180.0 / math.pi);
  }

  // Returns the rotated 3D position [x, y, z] (x = depth toward viewer).
  // Forward rotation brings the camera-centre coordinate onto the +X axis:
  // rotateZ(-rotationZ) then rotateY(+rotationX).
  List<double> _rotated(LatLng coords) {
    final lat = coords.latitude * math.pi / 180.0;
    final lon = coords.longitude * math.pi / 180.0;
    final cl = math.cos(lat);
    final x = radius * cl * math.cos(lon);
    final y = radius * cl * math.sin(lon);
    final z = radius * math.sin(lat);
    final r1 = _rotateZ(x, y, z, -rotationZ);
    return _rotateY(r1[0], r1[1], r1[2], rotationX);
  }

  // Inverse of [_rotated]: rotateY(-rotationX) then rotateZ(+rotationZ).
  List<double> _applyInverseRotation(double x, double y, double z) {
    final r1 = _rotateY(x, y, z, -rotationX);
    return _rotateZ(r1[0], r1[1], r1[2], rotationZ);
  }

  static List<double> _rotateY(double x, double y, double z, double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return [c * x + s * z, y, -s * x + c * z];
  }

  static List<double> _rotateZ(double x, double y, double z, double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return [c * x - s * y, s * x + c * y, z];
  }
}

/// Globe radius in pixels for a given [zoom] and [shortSide] of the viewport.
/// Diameter is 75% of the short side at zoom 1, doubling each zoom level.
double globeRadius(double zoom, double shortSide) =>
    shortSide * 0.375 * math.pow(2.0, zoom - 1.0);
