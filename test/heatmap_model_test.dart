// test/heatmap_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/goodmap.dart';

void main() {
  group('HeatmapId', () {
    test('equality is by value', () {
      expect(const HeatmapId(1), equals(const HeatmapId(1)));
      expect(const HeatmapId(1), isNot(equals(const HeatmapId(2))));
    });

    test('hashCode is consistent with equality', () {
      expect(const HeatmapId(7).hashCode, const HeatmapId(7).hashCode);
    });
  });

  group('HeatmapOptions', () {
    const p1 = LatLng(48.9, 2.35);
    const p2 = LatLng(51.5, -0.1);

    test('defaults are sensible', () {
      final opts = const HeatmapOptions(points: [p1, p2]);
      expect(opts.radius, 15.0);
      expect(opts.intensity, 1.0);
      expect(opts.opacity, 0.85);
      expect(opts.weights, isNull);
      expect(opts.gradient, isNull);
    });

    test('custom values are preserved', () {
      final opts = const HeatmapOptions(
        points: [p1],
        weights: [0.8],
        radius: 20.0,
        intensity: 1.5,
        opacity: 0.6,
      );
      expect(opts.radius, 20.0);
      expect(opts.intensity, 1.5);
      expect(opts.opacity, 0.6);
      expect(opts.weights, [0.8]);
    });

    test('points list is stored', () {
      final opts = const HeatmapOptions(points: [p1, p2]);
      expect(opts.points, hasLength(2));
      expect(opts.points.first, equals(p1));
    });
  });
}
