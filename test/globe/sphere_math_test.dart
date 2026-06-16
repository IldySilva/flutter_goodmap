import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart' show Vector3, Matrix4;
import 'package:mapcn_flutter/src/globe/sphere_math.dart';

void main() {
  test('lat/lng 0,0 maps to +X axis on the unit sphere', () {
    final v = latLngToUnitSphere(const LatLng(0, 0));
    expect(v.x, closeTo(1, 1e-9));
    expect(v.y, closeTo(0, 1e-9));
    expect(v.z, closeTo(0, 1e-9));
    expect(v.length, closeTo(1, 1e-9));
  });

  test('north pole maps to +Y', () {
    final v = latLngToUnitSphere(const LatLng(90, 0));
    expect(v.y, closeTo(1, 1e-9));
    expect(v.length, closeTo(1, 1e-9));
  });

  test('lng 90 maps to +Z', () {
    final v = latLngToUnitSphere(const LatLng(0, 90));
    expect(v.z, closeTo(1, 1e-9));
  });

  test('isFrontFacing: point under the camera is visible, antipode is not', () {
    final cam = Vector3(3, 0, 0);
    expect(isFrontFacing(Vector3(1, 0, 0), cam), isTrue);
    expect(isFrontFacing(Vector3(-1, 0, 0), cam), isFalse);
  });

  test('projectToScreen puts a point with identity matrix at viewport center', () {
    final mvp = Matrix4.identity();
    final p = projectToScreen(Vector3(0, 0, 0), mvp, const Size(200, 100));
    expect(p, isNotNull);
    expect(p!.dx, closeTo(100, 1e-6));
    expect(p.dy, closeTo(50, 1e-6));
  });

  test('projectToScreen returns null for a point with w<=0', () {
    final mvp = Matrix4.zero()
      ..setEntry(3, 2, -1) // w = -z
      ..setEntry(0, 0, 1)
      ..setEntry(1, 1, 1)
      ..setEntry(2, 2, 1);
    final behind = projectToScreen(Vector3(0, 0, 1), mvp, const Size(200, 100));
    expect(behind, isNull);
  });
}
