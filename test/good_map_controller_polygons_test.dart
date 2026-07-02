import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
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

  test('addPolygon returns an id and draws a native fill', () async {
    final id = controller.addPolygon(
      const PolygonOptions(
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 0)],
        color: Color(0xFFFF0000),
        opacity: 0.7,
      ),
    );
    expect(id, const PolygonId(0));
    await Future<void>.delayed(Duration.zero);
    final captured =
        verify(() => native.addFill(captureAny())).captured.single as FillOptions;
    expect(captured.fillColor, '#ff0000');
    expect(captured.fillOpacity, 0.7);
    // Ring is auto-closed (first point appended).
    expect(captured.geometry, const [
      [LatLng(0, 0), LatLng(0, 10), LatLng(10, 0), LatLng(0, 0)],
    ]);
  });

  test('addPolygon with holes passes all rings', () async {
    controller.addPolygon(
      const PolygonOptions(
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 0)],
        holes: [
          [LatLng(2, 2), LatLng(2, 4), LatLng(4, 2)],
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final captured =
        verify(() => native.addFill(captureAny())).captured.single as FillOptions;
    expect(captured.geometry!.length, 2);
  });

  test('addPolygon with outlineColor passes fillOutlineColor', () async {
    controller.addPolygon(
      const PolygonOptions(
        points: [LatLng(0, 0), LatLng(0, 10), LatLng(10, 0)],
        outlineColor: Color(0xFF000000),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final captured =
        verify(() => native.addFill(captureAny())).captured.single as FillOptions;
    expect(captured.fillOutlineColor, '#000000');
  });

  test('removePolygon with unknown id is a no-op', () async {
    controller.removePolygon(const PolygonId(99));
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => native.removeFill(any()));
  });

  test('removePolygon removes the native fill', () async {
    final id = controller.addPolygon(
      const PolygonOptions(points: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 0)]),
    );
    await Future<void>.delayed(Duration.zero);
    controller.removePolygon(id);
    verify(() => native.removeFill(any())).called(1);
  });

  test('clearPolygons removes every native fill', () async {
    controller.addPolygon(
      const PolygonOptions(points: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 0)]),
    );
    controller.addPolygon(
      const PolygonOptions(points: [LatLng(1, 1), LatLng(1, 2), LatLng(2, 1)]),
    );
    await Future<void>.delayed(Duration.zero);
    controller.clearPolygons();
    verify(() => native.removeFill(any())).called(2);
  });
}
