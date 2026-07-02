import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/lines/polygon.dart';

void main() {
  test('PolygonId equality is by value', () {
    expect(const PolygonId(5), const PolygonId(5));
    expect(const PolygonId(5) == const PolygonId(6), isFalse);
  });

  test('PolygonOptions defaults to green at 50% opacity', () {
    const o = PolygonOptions(points: [
      LatLng(0, 0),
      LatLng(0, 1),
      LatLng(1, 0),
    ]);
    expect(o.color, const Color(0xFF4CAF50));
    expect(o.opacity, 0.5);
    expect(o.outlineColor, isNull);
    expect(o.holes, isNull);
  });

  test('PolygonOptions.rings combines outer ring and holes', () {
    const outer = [LatLng(0, 0), LatLng(0, 10), LatLng(10, 0)];
    const hole1 = [LatLng(2, 2), LatLng(2, 4), LatLng(4, 2)];
    const hole2 = [LatLng(6, 6), LatLng(6, 8), LatLng(8, 6)];
    const o = PolygonOptions(
      points: outer,
      holes: [hole1, hole2],
    );
    expect(o.rings.length, 3);
    expect(o.rings[0], outer);
    expect(o.rings[1], hole1);
    expect(o.rings[2], hole2);
  });
}
