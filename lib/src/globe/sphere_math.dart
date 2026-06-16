import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart' show Vector3, Vector4, Matrix4;

/// Maps a geographic coordinate to a point on the unit sphere.
/// lat/lng (0,0) -> +X, north pole -> +Y, lng +90 -> +Z.
Vector3 latLngToUnitSphere(LatLng ll) {
  final lat = ll.latitude * math.pi / 180.0;
  final lng = ll.longitude * math.pi / 180.0;
  final cosLat = math.cos(lat);
  return Vector3(cosLat * math.cos(lng), math.sin(lat), cosLat * math.sin(lng));
}

/// True if a unit-sphere [point] is on the hemisphere facing [cameraPosition]
/// (i.e. in front of the globe's horizon, not occluded by the globe body).
bool isFrontFacing(Vector3 point, Vector3 cameraPosition) {
  final camLen = cameraPosition.length;
  if (camLen <= 1.0) return true; // inside/at surface: treat as visible
  final camDir = cameraPosition / camLen;
  return point.dot(camDir) > 1.0 / camLen;
}

/// Projects a world-space [point] through [viewProjection] to a screen offset
/// within [viewport]. Returns null if the point is behind the camera (w <= 0).
Offset? projectToScreen(Vector3 point, Matrix4 viewProjection, Size viewport) {
  final v = Vector4(point.x, point.y, point.z, 1.0);
  viewProjection.transform(v); // mutates v in place
  if (v.w <= 0) return null;
  final ndcX = v.x / v.w;
  final ndcY = v.y / v.w;
  return Offset(
    (ndcX * 0.5 + 0.5) * viewport.width,
    (1.0 - (ndcY * 0.5 + 0.5)) * viewport.height,
  );
}
