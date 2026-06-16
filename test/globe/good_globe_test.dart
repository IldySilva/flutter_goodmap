import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/globe/good_globe.dart';

void main() {
  testWidgets('horizontal drag changes the camera longitude', (tester) async {
    LatLng? seen;
    await tester.pumpWidget(MaterialApp(
      home: GoodGlobe(
        initialCenter: const LatLng(0, 0),
        onCameraChanged: (c) => seen = c,
        renderEnabled: false,
      ),
    ));
    await tester.drag(find.byType(GoodGlobe), const Offset(100, 0));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.longitude, isNot(0));
  });

  testWidgets('vertical drag changes latitude and clamps near the poles',
      (tester) async {
    LatLng? seen;
    await tester.pumpWidget(MaterialApp(
      home: GoodGlobe(
        initialCenter: const LatLng(0, 0),
        onCameraChanged: (c) => seen = c,
        renderEnabled: false,
      ),
    ));
    await tester.drag(find.byType(GoodGlobe), const Offset(0, 5000));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.latitude, lessThanOrEqualTo(85.0));
    expect(seen!.latitude, greaterThan(0));
  });
}
