// test/marker_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/markers/marker.dart';

void main() {
  test('MarkerId equality is by value', () {
    expect(const MarkerId(3), const MarkerId(3));
    expect(const MarkerId(3) == const MarkerId(4), isFalse);
  });

  test('MarkerImage.asset captures name and default size', () {
    final img = MarkerImage.asset('assets/pin.png');
    expect(img.assetName, 'assets/pin.png');
    expect(img.size, const Size(32, 32));
  });

  test('MarkerOptions defaults: center anchor, no child/image/onTap', () {
    const m = MarkerOptions(position: LatLng(1, 2));
    expect(m.position, const LatLng(1, 2));
    expect(m.alignment, Alignment.center);
    expect(m.child, isNull);
    expect(m.image, isNull);
    expect(m.onTap, isNull);
  });
}
