// lib/src/heatmap/heatmap.dart
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [GoodMapController.addHeatmap].
class HeatmapId {
  const HeatmapId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is HeatmapId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Options for a heatmap layer on the flat map.
///
/// A heatmap visualizes the density of geographic points using a colour gradient.
/// Provide [points] and optionally per-point [weights] (0..1). [radius] controls
/// the blur size, [intensity] controls the colour strength, and [opacity] fades
/// the whole layer.
class HeatmapOptions {
  const HeatmapOptions({
    required this.points,
    this.weights,
    this.radius = 15,
    this.intensity = 1,
    this.opacity = 0.85,
    this.gradient,
  });

  /// Geographic points for the heatmap.
  final List<LatLng> points;

  /// Optional per-point weight values in the range [0, 1]. Must match [points]
  /// in length if provided. Defaults to uniform weight 1.
  final List<double>? weights;

  /// Heatmap radius in pixels (MapLibre zoom-adjusted). Default: 15.
  final double radius;

  /// Heatmap intensity multiplier. Default: 1.
  final double intensity;

  /// Overall layer opacity [0, 1]. Default: 0.85.
  final double opacity;

  /// Custom colour gradient steps as MapLibre paint expression stops. When null
  /// the default blue → cyan → lime → yellow → red gradient is used.
  final List<dynamic>? gradient;
}
