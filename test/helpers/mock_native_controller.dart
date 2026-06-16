// test/helpers/mock_native_controller.dart
import 'dart:typed_data';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

class MockMapLibreMapController extends Mock implements MapLibreMapController {}

class _FallbackSymbol extends Fake implements Symbol {}

/// Call once in setUpAll before stubbing methods that take these types.
void registerMapcnFallbacks() {
  registerFallbackValue(CameraUpdate.zoomIn());
  registerFallbackValue(const SymbolOptions());
  registerFallbackValue(const LatLng(0, 0));
  registerFallbackValue(_FallbackSymbol()); // for removeSymbol(symbol) stubs
  registerFallbackValue(Uint8List(0)); // for addImage(bytes) stubs
}
