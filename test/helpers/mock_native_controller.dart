// test/helpers/mock_native_controller.dart
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

class MockMapLibreMapController extends Mock implements MapLibreMapController {}

/// Call once in setUpAll before stubbing methods that take these types.
void registerMapcnFallbacks() {
  registerFallbackValue(CameraUpdate.zoomIn());
  registerFallbackValue(const SymbolOptions());
  registerFallbackValue(const LatLng(0, 0));
  registerFallbackValue(const SymbolOptions()); // for Symbol stubs if needed
}
