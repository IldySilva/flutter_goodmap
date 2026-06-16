// test/helpers/mock_native_controller.dart
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:goodmap/src/good_map.dart';
import 'package:mocktail/mocktail.dart';

class MockMapLibreMapController extends Mock implements MapLibreMapController {}

/// Builds a fake map: ignores rendering, immediately invokes onMapCreated and
/// onStyleLoaded with [native], and reports the chosen style string.
GoodMapBuilder testMapBuilder(
  MapLibreMapController native, {
  void Function(String style)? onStyle,
}) {
  return ({
    required String styleString,
    required CameraPosition initialCameraPosition,
    required void Function(MapLibreMapController) onMapCreated,
    required void Function() onStyleLoaded,
    required void Function(CameraPosition) onCameraMove,
  }) {
    onStyle?.call(styleString);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onMapCreated(native);
      onStyleLoaded();
    });
    return const SizedBox.expand();
  };
}

class _FallbackSymbol extends Fake implements Symbol {}

class _FallbackLine extends Fake implements Line {}

/// Call once in setUpAll before stubbing methods that take these types.
void registerGoodFallbacks() {
  registerFallbackValue(CameraUpdate.zoomIn());
  registerFallbackValue(const SymbolOptions());
  registerFallbackValue(const LatLng(0, 0));
  registerFallbackValue(_FallbackSymbol()); // for removeSymbol(symbol) stubs
  registerFallbackValue(Uint8List(0)); // for addImage(bytes) stubs
  registerFallbackValue(const LineOptions()); // for addLine(options) stubs
  registerFallbackValue(_FallbackLine()); // for removeLine(line) stubs
}
