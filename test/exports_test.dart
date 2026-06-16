// test/exports_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/goodmap.dart';

void main() {
  test('public surface is exported', () {
    // Compile-time check: referencing these confirms they are exported.
    expect(GoodMap, isNotNull);
    expect(GoodGlobe, isNotNull);
    expect(GoodControls, isNotNull);
    expect(GoodMapTheme, isNotNull);
    expect(GoodMapController, isNotNull);
    expect(MarkerOptions, isNotNull);
    expect(MarkerImage, isNotNull);
    expect(MarkerId, isNotNull);
    expect(PopupId, isNotNull);
    expect(LatLng, isNotNull); // re-exported from maplibre_gl
    expect(LatLngBounds, isNotNull); // re-exported from maplibre_gl
    expect(CameraPosition, isNotNull);
  });
}
