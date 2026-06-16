// lib/src/popups/popup.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [MapcnController.showPopup].
@immutable
class PopupId {
  const PopupId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is PopupId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Describes a popup overlay anchored to a geographic position.
@immutable
class PopupOptions {
  const PopupOptions({
    required this.position,
    required this.child,
    this.alignment = Alignment.bottomCenter,
  });

  final LatLng position;
  final Widget child;
  final Alignment alignment;
}
