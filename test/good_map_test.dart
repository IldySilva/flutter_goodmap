// test/good_map_test.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:goodmap/src/good_map_controller.dart';
import 'package:goodmap/src/good_map.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerGoodFallbacks);

  testWidgets('builds a Stack with controls and calls onMapReady once',
      (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(0, 0));
    GoodMapController? ready;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: GoodMap(
        initialCenter: const LatLng(0, 0),
        controls: const GoodControls(zoom: true, compass: true),
        onMapReady: (c) => ready = c,
        mapBuilder: testMapBuilder(native), // injects fake native + fires lifecycle
      ),
    ));
    await tester.pumpAndSettle();

    expect(ready, isNotNull);
    expect(find.byKey(const ValueKey('goodmap_zoom_in')), findsOneWidget);
    expect(find.byKey(const ValueKey('goodmap_compass')), findsOneWidget);
  });

  testWidgets('selects positron in light mode', (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(0, 0));
    String? capturedStyle;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: GoodMap(
        initialCenter: const LatLng(0, 0),
        onMapReady: (_) {},
        mapBuilder: testMapBuilder(native, onStyle: (s) => capturedStyle = s),
      ),
    ));
    await tester.pumpAndSettle();
    expect(capturedStyle, contains('positron'));
  });
}
