// test/basemaps_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/src/theme/basemaps.dart';

void main() {
  test('light brightness selects the positron basemap', () {
    expect(basemapStyleFor(Brightness.light), Basemaps.positron);
    expect(Basemaps.positron, contains('positron'));
  });

  test('dark brightness selects the dark-matter basemap', () {
    expect(basemapStyleFor(Brightness.dark), Basemaps.darkMatter);
    expect(Basemaps.darkMatter, contains('dark-matter'));
  });
}
