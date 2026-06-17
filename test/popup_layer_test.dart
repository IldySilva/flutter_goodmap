// test/popup_layer_test.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:goodmap/src/good_map_controller.dart';
import 'package:goodmap/src/popups/popup_layer.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerGoodFallbacks);

  testWidgets('positions an overlay entry at the projected screen offset',
      (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(120, 240));

    final entries = [
      const OverlayEntryData(
        key: ValueKey('p'),
        position: LatLng(1, 2),
        alignment: Alignment.topLeft, // zero anchor translation -> exact offset
        child: SizedBox(key: ValueKey('child'), width: 10, height: 10),
      ),
    ];

    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        GoodOverlayLayer(native: native, entries: entries, cameraVersion: 0),
      ]),
    ));
    await tester.pumpAndSettle();

    final pos = tester.getTopLeft(find.byKey(const ValueKey('child')));
    expect(pos.dx, moreOrLessEquals(120, epsilon: 0.5));
    expect(pos.dy, moreOrLessEquals(240, epsilon: 0.5));
  });


  testWidgets('invokes onTap when the overlay child is tapped', (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(50, 50));
    var tapped = false;

    final entries = [
      OverlayEntryData(
        key: const ValueKey('m'),
        position: const LatLng(0, 0),
        alignment: Alignment.topLeft,
        onTap: () => tapped = true,
        child: const SizedBox(key: ValueKey('hit'), width: 40, height: 40),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        GoodOverlayLayer(native: native, entries: entries, cameraVersion: 0),
      ]),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hit')));
    expect(tapped, isTrue);
  });
}
