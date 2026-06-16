// test/exports_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() {
  test('public surface is exported', () {
    // Compile-time check: referencing these confirms they are exported.
    expect(MapcnMap, isNotNull);
    expect(MapcnGlobe, isNotNull);
    expect(MapcnControls, isNotNull);
    expect(MapcnTheme, isNotNull);
    expect(MapcnController, isNotNull);
    expect(MarkerOptions, isNotNull);
    expect(MarkerImage, isNotNull);
    expect(MarkerId, isNotNull);
    expect(PopupId, isNotNull);
    expect(LatLng, isNotNull); // re-exported from maplibre_gl
    expect(LatLngBounds, isNotNull); // re-exported from maplibre_gl
    expect(CameraPosition, isNotNull);
  });
}
