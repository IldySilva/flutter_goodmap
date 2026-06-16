import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

class _FakeLine extends Fake implements Line {}

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.addLine(any())).thenAnswer((_) async => _FakeLine());
    when(() => native.removeLine(any())).thenAnswer((_) async {});
    controller = MapcnController(native);
  });

  test('addPolyline returns an id and draws a native line', () async {
    final id = controller.addPolyline(
      const [LatLng(0, 0), LatLng(1, 1)],
      color: const Color(0xFFFF0000),
      width: 6,
    );
    expect(id, const PolylineId(0));
    await Future<void>.delayed(Duration.zero); // let async line creation run
    final captured =
        verify(() => native.addLine(captureAny())).captured.single as LineOptions;
    expect(captured.geometry, const [LatLng(0, 0), LatLng(1, 1)]);
    expect(captured.lineColor, '#ff0000');
    expect(captured.lineWidth, 6);
  });

  test('removePolyline with unknown id is a no-op', () async {
    controller.removePolyline(const PolylineId(99)); // must not throw
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => native.removeLine(any()));
  });

  test('removePolyline removes the native line', () async {
    final id = controller.addPolyline(const [LatLng(0, 0), LatLng(1, 1)]);
    await Future<void>.delayed(Duration.zero);
    controller.removePolyline(id);
    verify(() => native.removeLine(any())).called(1);
  });

  test('clearPolylines removes every native line', () async {
    controller.addPolyline(const [LatLng(0, 0), LatLng(1, 1)]);
    controller.addPolyline(const [LatLng(2, 2), LatLng(3, 3)]);
    await Future<void>.delayed(Duration.zero);
    controller.clearPolylines();
    verify(() => native.removeLine(any())).called(2);
  });
}
