// test/mapcn_controller_popups_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:goodmap/src/good_map_controller.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerGoodFallbacks);

  late MockMapLibreMapController native;
  late GoodMapController controller;

  setUp(() {
    native = MockMapLibreMapController();
    controller = GoodMapController(native);
  });

  test('showPopup returns an id and appends an overlay entry', () {
    final id = controller.showPopup(const LatLng(1, 2), const Text('hello'));
    expect(id, const PopupId(0));
    expect(controller.overlayEntries.length, 1);
    expect(controller.overlayEntries.single.alignment, Alignment.bottomCenter);
  });

  test('hidePopup removes the entry; unknown id is a no-op', () {
    final id = controller.showPopup(const LatLng(1, 2), const Text('hello'));
    controller.hidePopup(const PopupId(99)); // no-op
    expect(controller.overlayEntries.length, 1);
    controller.hidePopup(id);
    expect(controller.overlayEntries, isEmpty);
  });

  test('overlayEntries merges child-markers and popups', () {
    controller.addMarker(const MarkerOptions(position: LatLng(0, 0), child: Text('m')));
    controller.showPopup(const LatLng(1, 1), const Text('p'));
    expect(controller.overlayEntries.length, 2);
  });

  test('clearPopups empties popups but keeps markers', () {
    controller.addMarker(const MarkerOptions(position: LatLng(0, 0), child: Text('m')));
    controller.showPopup(const LatLng(1, 1), const Text('p'));
    controller.clearPopups();
    expect(controller.overlayEntries.length, 1);
  });
}
