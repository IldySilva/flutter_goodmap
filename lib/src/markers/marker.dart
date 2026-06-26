// lib/src/markers/marker.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [GoodMapController.addMarker].
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
///
/// **Pulse animation** — set [pulse] to true to show an animated ripple ring
/// around the dot on the globe. [pulseMaxRadius] controls how large the ring
/// grows before resetting.
///
/// **Time-series** — set [timestamp] (any consistent unit: epoch seconds, step
/// index, etc.) so that the globe's `timeRange` filter can show/hide this marker
/// dynamically.
@immutable
class MarkerOptions {
  const MarkerOptions({
    required this.position,
    this.child,
    this.image,
    this.alignment = Alignment.center,
    this.onTap,
    this.label,
    this.color,
    this.radius,
    this.pulse = false,
    this.pulseMaxRadius,
    this.timestamp,
  });

  final LatLng position;
  final Widget? child;
  final MarkerImage? image;
  final Alignment alignment;
  final VoidCallback? onTap;

  /// Optional text label (used for simple point-labels on the globe or flat map).
  final String? label;

  /// Optional color (used for fallback dot markers).
  final Color? color;

  /// Optional radius (used for fallback dot markers).
  final double? radius;

  /// When true, draws an animated ripple ring around the marker dot on the globe.
  final bool pulse;

  /// Maximum radius (px) the pulse ring grows to before resetting.
  /// Defaults to 5× [radius] (or 20 if [radius] is null).
  final double? pulseMaxRadius;

  /// Optional timestamp for time-series filtering via [GoodGlobe.timeRange].
  /// Can be any consistent unit (epoch seconds, frame index, custom).
  final double? timestamp;
}

/// A labelled point plotted on the globe (deprecated: use [MarkerOptions] instead).
@Deprecated('Use MarkerOptions instead')
@immutable
class GlobePoint extends MarkerOptions {
  const GlobePoint({
    required LatLng coordinate,
    super.label,
    super.color = const Color(0xFF4F86F7),
    super.radius = 4,
  }) : super(
          position: coordinate,
        );

  LatLng get coordinate => position;
}
