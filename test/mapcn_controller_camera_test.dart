// test/mapcn_controller_camera_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.animateCamera(any())).thenAnswer((_) async => true);
    when(() => native.moveCamera(any())).thenAnswer((_) async => true);
    controller = MapcnController(native);
  });

  test('flyTo animates to the target with zoom', () async {
    await controller.flyTo(const LatLng(10, 20), zoom: 14);
    verify(() => native.animateCamera(any())).called(1);
    verifyNever(() => native.moveCamera(any()));
  });

  test('moveTo moves the camera without animation', () async {
    await controller.moveTo(const LatLng(10, 20));
    verify(() => native.moveCamera(any())).called(1);
    verifyNever(() => native.animateCamera(any()));
  });

  test('animateTo animates to a full CameraPosition', () async {
    await controller.animateTo(const CameraPosition(target: LatLng(1, 2), zoom: 9));
    verify(() => native.animateCamera(any())).called(1);
  });

  test('fitBounds animates to bounds', () async {
    await controller.fitBounds(
      LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(1, 1)),
    );
    verify(() => native.animateCamera(any())).called(1);
  });
}
