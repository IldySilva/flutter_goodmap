// test/sun_position_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

// Access the static helpers via a thin shim — import the internal file directly
// since this is a package-internal test.
import 'package:goodmap/src/globe/sphere_shader_painter.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

void main() {
  group('SphereShaderPainter.sunPositionFromDateTime', () {
    test('at June solstice noon UTC, declination ≈ +23.45° and lng ≈ 0°', () {
      // ~21 June = day 172; solstice declination is max positive.
      final pos = SphereShaderPainter.sunPositionFromDateTime(
        DateTime.utc(2024, 6, 21, 12, 0, 0),
      );
      // Declination should be close to +23.45° (within 1°).
      expect(pos.latitude, closeTo(23.45, 1.0));
      // At 12:00 UTC, subsolar longitude should be near 0°.
      expect(pos.longitude.abs(), lessThan(5.0));
    });

    test('at December solstice noon UTC, declination ≈ -23.45°', () {
      final pos = SphereShaderPainter.sunPositionFromDateTime(
        DateTime.utc(2024, 12, 21, 12, 0, 0),
      );
      expect(pos.latitude, closeTo(-23.45, 1.0));
    });

    test('at equinox, declination ≈ 0°', () {
      // ~20 March equinox
      final pos = SphereShaderPainter.sunPositionFromDateTime(
        DateTime.utc(2024, 3, 20, 12, 0, 0),
      );
      expect(pos.latitude.abs(), lessThan(3.0));
    });

    test('at 00:00 UTC, subsolar longitude ≈ -180° (or +180°)', () {
      // At midnight UTC, sun is on the opposite side (near the date line).
      final pos = SphereShaderPainter.sunPositionFromDateTime(
        DateTime.utc(2024, 6, 21, 0, 0, 0),
      );
      expect(pos.longitude.abs(), closeTo(180.0, 5.0));
    });
  });

  group('SphereShaderPainter.sunDirectionVector', () {
    test('subsolar point at equator/prime-meridian gives unit vector (1,0,0)', () {
      final (x, y, z) =
          SphereShaderPainter.sunDirectionVector(const LatLng(0, 0));
      expect(x, closeTo(1.0, 1e-10));
      expect(y, closeTo(0.0, 1e-10));
      expect(z, closeTo(0.0, 1e-10));
    });

    test('north pole subsolar point gives unit vector (0,0,1)', () {
      final (x, y, z) =
          SphereShaderPainter.sunDirectionVector(const LatLng(90, 0));
      expect(x, closeTo(0.0, 1e-10));
      expect(y, closeTo(0.0, 1e-10));
      expect(z, closeTo(1.0, 1e-10));
    });

    test('vector has unit length', () {
      final (x, y, z) =
          SphereShaderPainter.sunDirectionVector(const LatLng(35.0, -97.0));
      final len = math.sqrt(x * x + y * y + z * z);
      expect(len, closeTo(1.0, 1e-9));
    });
  });
}
