// test/mapcn_controller_markers_test.dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

class _FakeSymbol extends Fake implements Symbol {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    // Serve a fake asset so MarkerImage.asset() rootBundle.load(...) resolves.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      return ByteData.view(Uint8List.fromList(<int>[0, 1, 2, 3]).buffer);
    });
    native = MockMapLibreMapController();
    when(() => native.addImage(any(), any())).thenAnswer((_) async {});
    when(() => native.addSymbol(any())).thenAnswer((_) async => _FakeSymbol());
    when(() => native.removeSymbol(any())).thenAnswer((_) async {});
    controller = MapcnController(native);
  });

  test('addMarker with child returns an id and exposes an overlay entry', () {
    final id = controller.addMarker(
      const MarkerOptions(position: LatLng(1, 2), child: Text('hi')),
    );
    expect(id, const MarkerId(0));
    expect(controller.overlayEntries.length, 1);
    expect(controller.overlayEntries.single.position, const LatLng(1, 2));
  });

  test('addMarker with image creates a GL symbol, no overlay entry', () async {
    controller.addMarker(
      MarkerOptions(position: const LatLng(1, 2), image: MarkerImage.asset('a.png')),
    );
    await Future<void>.delayed(Duration.zero); // let async symbol creation run
    verify(() => native.addImage(any(), any())).called(1);
    verify(() => native.addSymbol(any())).called(1);
    expect(controller.overlayEntries, isEmpty);
  });

  test('removeMarker with unknown id is a no-op', () {
    controller.removeMarker(const MarkerId(99)); // must not throw
    expect(controller.overlayEntries, isEmpty);
  });

  test('updateMarker replaces options for an existing child marker', () {
    final id = controller.addMarker(
      const MarkerOptions(position: LatLng(1, 2), child: Text('a')),
    );
    controller.updateMarker(id, const MarkerOptions(position: LatLng(3, 4), child: Text('b')));
    expect(controller.overlayEntries.single.position, const LatLng(3, 4));
  });

  test('clearMarkers empties overlay entries and removes GL symbols', () async {
    controller.addMarker(const MarkerOptions(position: LatLng(1, 2), child: Text('a')));
    controller.addMarker(
      MarkerOptions(position: const LatLng(3, 4), image: MarkerImage.asset('a.png')),
    );
    await Future<void>.delayed(Duration.zero);
    controller.clearMarkers();
    await Future<void>.delayed(Duration.zero);
    expect(controller.overlayEntries, isEmpty);
    verify(() => native.removeSymbol(any())).called(1);
  });
}
