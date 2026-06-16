import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/lines/polyline.dart';

void main() {
  test('PolylineId equality is by value', () {
    expect(const PolylineId(5), const PolylineId(5));
    expect(const PolylineId(5) == const PolylineId(6), isFalse);
  });

  test('PolylineOptions defaults to indigo width 4', () {
    const o = PolylineOptions(points: [LatLng(0, 0), LatLng(1, 1)]);
    expect(o.color, const Color(0xFF3F51B5));
    expect(o.width, 4);
    expect(o.points.length, 2);
  });
}
