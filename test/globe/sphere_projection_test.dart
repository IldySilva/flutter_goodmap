import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/globe/sphere_projection.dart';

double _rad(double deg) => deg * math.pi / 180.0;

void main() {
  const center = Offset(200, 200);
  const radius = 150.0;

  SphereProjection projFor(LatLng c) => SphereProjection(
        center: center,
        radius: radius,
        rotationX: _rad(c.latitude),
        rotationZ: _rad(c.longitude),
      );

  test('the camera-centre coordinate projects to the screen centre', () {
    const c = LatLng(20, 50);
    final p = projFor(c).project(c);
    expect(p, isNotNull);
    expect(p!.dx, closeTo(center.dx, 0.5));
    expect(p.dy, closeTo(center.dy, 0.5));
  });

  test('the centre is visible and its antipode is occluded', () {
    const c = LatLng(0, 0);
    final proj = projFor(c);
    expect(proj.isVisible(const LatLng(0, 0)), isTrue);
    expect(proj.isVisible(const LatLng(0, 180)), isFalse);
  });

  test('project then unproject round-trips for a front-facing point', () {
    const c = LatLng(10, 20);
    final proj = projFor(c);
    const p = LatLng(15, 35);
    final screen = proj.project(p);
    expect(screen, isNotNull);
    final back = proj.unproject(screen!);
    expect(back, isNotNull);
    expect(back!.latitude, closeTo(p.latitude, 0.01));
    expect(back.longitude, closeTo(p.longitude, 0.01));
  });

  test('unproject returns null outside the globe disc', () {
    final proj = projFor(const LatLng(0, 0));
    expect(proj.unproject(const Offset(400, 400)), isNull);
  });

  test('globeRadius doubles per zoom level', () {
    expect(globeRadius(2, 800), closeTo(globeRadius(1, 800) * 2, 1e-6));
  });
}
