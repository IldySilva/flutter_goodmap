// lib/src/markers/marker.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [MapcnController.addMarker].
@immutable
class MarkerId {
  const MarkerId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is MarkerId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// An asset image baked into the GL scene as a symbol icon (static, performant
/// for many markers). The default rich-widget path uses [MarkerOptions.child].
@immutable
class MarkerImage {
  const MarkerImage._(this.assetName, this.size);
  final String assetName;
  final Size size;

  factory MarkerImage.asset(String assetName, {Size size = const Size(32, 32)}) =>
      MarkerImage._(assetName, size);
}

/// Describes a marker. Provide [child] for an interactive overlay widget
/// (default) OR [image] for a static GL-scene symbol.
@immutable
class MarkerOptions {
  const MarkerOptions({
    required this.position,
    this.child,
    this.image,
    this.alignment = Alignment.center,
    this.onTap,
  });

  final LatLng position;
  final Widget? child;
  final MarkerImage? image;
  final Alignment alignment;
  final VoidCallback? onTap;
}
