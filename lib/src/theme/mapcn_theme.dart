// lib/src/theme/mapcn_theme.dart
import 'package:flutter/material.dart';

/// Pure data: marker/popup/control styling tokens derived from a [ColorScheme].
/// All fields are overridable via [copyWith] or the [MapcnTheme] constructor.
@immutable
class MapcnTheme {
  const MapcnTheme({
    required this.markerColor,
    required this.popupBackground,
    required this.popupBorder,
    required this.popupRadius,
    required this.controlBackground,
    required this.controlForeground,
  });

  final Color markerColor;
  final Color popupBackground;
  final Color popupBorder;
  final Radius popupRadius;
  final Color controlBackground;
  final Color controlForeground;

  factory MapcnTheme.fromColorScheme(ColorScheme scheme) => MapcnTheme(
        markerColor: scheme.primary,
        popupBackground: scheme.surface,
        popupBorder: scheme.outlineVariant,
        popupRadius: const Radius.circular(12),
        controlBackground: scheme.surface,
        controlForeground: scheme.onSurface,
      );

  MapcnTheme copyWith({
    Color? markerColor,
    Color? popupBackground,
    Color? popupBorder,
    Radius? popupRadius,
    Color? controlBackground,
    Color? controlForeground,
  }) =>
      MapcnTheme(
        markerColor: markerColor ?? this.markerColor,
        popupBackground: popupBackground ?? this.popupBackground,
        popupBorder: popupBorder ?? this.popupBorder,
        popupRadius: popupRadius ?? this.popupRadius,
        controlBackground: controlBackground ?? this.controlBackground,
        controlForeground: controlForeground ?? this.controlForeground,
      );
}
