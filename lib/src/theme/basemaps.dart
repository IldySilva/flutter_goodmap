// lib/src/theme/basemaps.dart
import 'package:flutter/material.dart' show Brightness;

/// CARTO public vector basemap style URLs (free for dev/demo use; see README).
abstract final class Basemaps {
  static const String positron =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
  static const String darkMatter =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
}

/// Selects the basemap style URL matching the host app's [brightness].
String basemapStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? Basemaps.darkMatter : Basemaps.positron;
