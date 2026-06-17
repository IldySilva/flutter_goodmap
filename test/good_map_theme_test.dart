// test/good_map_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/src/theme/good_map_theme.dart';

void main() {
  test('fromColorScheme derives tokens from the scheme', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final theme = GoodMapTheme.fromColorScheme(scheme);

    expect(theme.markerColor, scheme.primary);
    expect(theme.popupBackground, scheme.surface);
    expect(theme.popupBorder, scheme.outlineVariant);
    expect(theme.controlBackground, scheme.surface);
    expect(theme.controlForeground, scheme.onSurface);
    expect(theme.popupRadius, const Radius.circular(12));
  });

  test('copyWith overrides only the given tokens', () {
    final base = GoodMapTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: Colors.indigo));
    final overridden = base.copyWith(markerColor: Colors.red);

    expect(overridden.markerColor, Colors.red);
    expect(overridden.popupBackground, base.popupBackground);
  });
}
