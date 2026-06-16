// test/popup_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/popups/popup.dart';

void main() {
  test('PopupId equality is by value', () {
    expect(const PopupId(7), const PopupId(7));
    expect(const PopupId(7) == const PopupId(8), isFalse);
  });

  test('PopupOptions defaults to bottomCenter anchor', () {
    const p = PopupOptions(position: LatLng(1, 2), child: SizedBox());
    expect(p.alignment, Alignment.bottomCenter);
    expect(p.position, const LatLng(1, 2));
  });
}
