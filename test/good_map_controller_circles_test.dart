import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide CircleOptions;
import 'package:goodmap/src/good_map_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

class _FakeFill extends Fake implements Fill {}

void main() {
  setUpAll(registerGoodFallbacks);

  late MockMapLibreMapController native;
  late GoodMapController controller;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.addFill(any())).thenAnswer((_) async => _FakeFill());
    when(() => native.removeFill(any())).thenAnswer((_) async {});
    controller = GoodMapController(native);
  });

  test('addCircle returns an id and draws a native fill', () async {
    final id = controller.addCircle(
      const CircleOptions(
        center: LatLng(48.85, 2.35),
        radiusMeters: 5000,
        color: Color(0xFF00FF00),
        opacity: 0.5,
      ),
    );
    expect(id, const CircleId(0));
    await Future<void>.delayed(Duration.zero);
    final captured =
        verify(() => native.addFill(captureAny())).captured.single
            as FillOptions;
    expect(captured.fillColor, '#00ff00');
    expect(captured.fillOpacity, 0.5);
    // Geometry should be a closed ring (first == last).
    final ring = captured.geometry!.single;
    expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-10));
    expect(ring.first.longitude, closeTo(ring.last.longitude, 1e-10));
  });

  test('addCircle with outlineColor passes fillOutlineColor', () async {
    controller.addCircle(
      const CircleOptions(
        center: LatLng(0, 0),
        radiusMeters: 1000,
        outlineColor: Color(0xFFFF0000),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final captured =
        verify(() => native.addFill(captureAny())).captured.single
            as FillOptions;
    expect(captured.fillOutlineColor, '#ff0000');
  });

  test('removeCircle with unknown id is a no-op', () async {
    controller.removeCircle(const CircleId(99));
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => native.removeFill(any()));
  });

  test('removeCircle removes the native fill', () async {
    final id = controller.addCircle(
      const CircleOptions(center: LatLng(0, 0), radiusMeters: 1000),
    );
    await Future<void>.delayed(Duration.zero);
    controller.removeCircle(id);
    verify(() => native.removeFill(any())).called(1);
  });

  test('clearCircles removes every native fill', () async {
    controller.addCircle(
      const CircleOptions(center: LatLng(0, 0), radiusMeters: 1000),
    );
    controller.addCircle(
      const CircleOptions(center: LatLng(1, 1), radiusMeters: 2000),
    );
    await Future<void>.delayed(Duration.zero);
    controller.clearCircles();
    verify(() => native.removeFill(any())).called(2);
  });
}
