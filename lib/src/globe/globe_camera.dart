import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Size;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart'
    show Vector3, Matrix4, makePerspectiveMatrix, makeViewMatrix;

import 'sphere_math.dart';

/// Distance of the camera from the globe centre for a given [zoom].
/// Monotonically decreasing in zoom; always > 1 (outside the unit sphere).
double cameraDistance(double zoom) => 1.1 + 6.0 * math.pow(0.5, zoom).toDouble();

/// Orbit-camera state. The v1 spike uses bearing/tilt = 0; the fields exist so
/// later phases can add rotation/pitch without an API change.
class GlobeCamera {
  const GlobeCamera({
    required this.center,
    this.zoom = 2,
    this.bearing = 0,
    this.tilt = 0,
  });

  final LatLng center;
  final double zoom;
  final double bearing;
  final double tilt;

  Vector3 eyePosition() => latLngToUnitSphere(center) * cameraDistance(zoom);

  /// Combined view*projection matrix for a [viewport] of the given size.
  Matrix4 viewProjection(Size viewport) {
    final aspect = viewport.width / viewport.height;
    final proj = makePerspectiveMatrix(45 * math.pi / 180, aspect, 0.01, 100);
    final eye = eyePosition();
    // Up is world +Y, except looking straight down a pole where +Y is degenerate.
    final up = center.latitude.abs() > 89.0 ? Vector3(0, 0, 1) : Vector3(0, 1, 0);
    final view = makeViewMatrix(eye, Vector3.zero(), up);
    return proj * view;
  }

  GlobeCamera copyWith({
    LatLng? center,
    double? zoom,
    double? bearing,
    double? tilt,
  }) =>
      GlobeCamera(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        bearing: bearing ?? this.bearing,
        tilt: tilt ?? this.tilt,
      );
}
