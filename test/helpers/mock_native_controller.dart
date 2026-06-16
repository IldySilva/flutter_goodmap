// test/helpers/mock_native_controller.dart
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_map.dart';
import 'package:mocktail/mocktail.dart';

class MockMapLibreMapController extends Mock implements MapLibreMapController {}

/// Builds a fake map: ignores rendering, immediately invokes onMapCreated and
/// onStyleLoaded with [native], and reports the chosen style string.
MapcnMapBuilder testMapBuilder(
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

/// Call once in setUpAll before stubbing methods that take these types.
void registerMapcnFallbacks() {
  registerFallbackValue(CameraUpdate.zoomIn());
  registerFallbackValue(const SymbolOptions());
  registerFallbackValue(const LatLng(0, 0));
  registerFallbackValue(_FallbackSymbol()); // for removeSymbol(symbol) stubs
  registerFallbackValue(Uint8List(0)); // for addImage(bytes) stubs
}
