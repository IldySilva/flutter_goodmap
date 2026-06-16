import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/globe/globe_camera.dart';
import 'package:mapcn_flutter/src/globe/sphere_math.dart';

void main() {
  test('cameraDistance decreases as zoom increases (zoom in = closer)', () {
    expect(cameraDistance(4) < cameraDistance(1), isTrue);
    expect(cameraDistance(1) > 1.0, isTrue);
  });

  test('eye sits outside the sphere along the center normal', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2);
    final eye = cam.eyePosition();
    expect(eye.length, greaterThan(1.0));
    expect(eye.x, greaterThan(0));
  });

  test('the camera center projects to the middle of the viewport', () {
    const cam = GlobeCamera(center: LatLng(10, 20), zoom: 2);
    const size = Size(400, 400);
    final mvp = cam.viewProjection(size);
    final screen = projectToScreen(latLngToUnitSphere(cam.center), mvp, size);
    expect(screen, isNotNull);
    expect(screen!.dx, closeTo(200, 2));
    expect(screen.dy, closeTo(200, 2));
  });

  test('the antipodal point is occluded by the globe body', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2);
    final back = latLngToUnitSphere(const LatLng(0, 180));
    expect(isFrontFacing(back, cam.eyePosition()), isFalse);
  });

  test('copyWith overrides only the given fields', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2, bearing: 0);
    final c2 = cam.copyWith(zoom: 5);
    expect(c2.zoom, 5);
    expect(c2.center, cam.center);
  });
}
