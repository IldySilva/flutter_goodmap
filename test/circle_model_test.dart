import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/lines/circle.dart';

void main() {
  test('CircleId equality is by value', () {
    expect(const CircleId(3), const CircleId(3));
    expect(const CircleId(3) == const CircleId(4), isFalse);
  });

  test('CircleOptions defaults to blue at 30% opacity, 64 segments', () {
    const o = CircleOptions(
      center: LatLng(0, 0),
      radiusMeters: 1000,
    );
    expect(o.color, const Color(0xFF4F86F7));
    expect(o.opacity, 0.3);
    expect(o.segments, 64);
    expect(o.outlineColor, isNull);
  });

  test('buildCirclePoints returns closed ring with expected length', () {
    const center = LatLng(0, 0);
    final points = CircleOptions.buildCirclePoints(
      center,
      1000,
      segments: 4,
    );
    // 4 segments → 5 points (closed: first = last)
    expect(points.length, 5);
    expect(points.first.latitude, closeTo(points.last.latitude, 1e-10));
    expect(points.first.longitude, closeTo(points.last.longitude, 1e-10));
  });

  test('buildCirclePoints produces roughly circular shape', () {
    const center = LatLng(48.85, 2.35);
    const radius = 5000.0;
    final points = CircleOptions.buildCirclePoints(
      center,
      radius,
      segments: 32,
    );
    // All points should be within ~1% of the target distance from center.
    const er = 6_371_000;
    for (final p in points.take(10)) {
      // Approximate great-circle distance.
      final dlat = (p.latitude - center.latitude) * math.pi / 180;
      final dlon = (p.longitude - center.longitude) * math.pi / 180;
      final a = math.sin(dlat / 2) * math.sin(dlat / 2) +
          math.cos(center.latitude * math.pi / 180) *
              math.cos(p.latitude * math.pi / 180) *
              math.sin(dlon / 2) *
              math.sin(dlon / 2);
      final dist = 2 * er * math.asin(math.sqrt(a));
      expect(dist, closeTo(radius, radius * 0.02));
    }
  });

  test('polygonPoints convenience getter matches buildCirclePoints', () {
    const o = CircleOptions(
      center: LatLng(10, 20),
      radiusMeters: 500,
      segments: 16,
    );
    final fromGetter = o.polygonPoints;
    final fromStatic = CircleOptions.buildCirclePoints(
      o.center,
      o.radiusMeters,
      segments: o.segments,
    );
    expect(fromGetter, fromStatic);
  });
}
