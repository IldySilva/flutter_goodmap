import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/src/globe/detail_tile_atlas.dart';
import 'package:goodmap/src/globe/sphere_projection.dart';

void main() {
  group('DetailBounds tests', () {
    test('DetailBounds equality and hashCode', () {
      const bounds1 = DetailBounds(
        minLon: 1.0,
        maxLon: 2.0,
        minLat: 3.0,
        maxLat: 4.0,
      );

      const bounds2 = DetailBounds(
        minLon: 1.0,
        maxLon: 2.0,
        minLat: 3.0,
        maxLat: 4.0,
      );

      const bounds3 = DetailBounds(
        minLon: 1.5,
        maxLon: 2.0,
        minLat: 3.0,
        maxLat: 4.0,
      );

      expect(bounds1, equals(bounds2));
      expect(bounds1.hashCode, equals(bounds2.hashCode));

      expect(bounds1, isNot(equals(bounds3)));
      expect(bounds1.hashCode, isNot(equals(bounds3.hashCode)));
    });
  });

  group('DetailTileAtlas.calculateVisibleBounds tests', () {
    test('calculateVisibleBounds return 0 bounds if nothing is visible', () {
      // Create a viewport projection far off, making it invisible
      const projection = SphereProjection(
        center: Offset(500, 500),
        radius: 10.0,
        rotationX: 0.0,
        rotationZ: 0.0,
      );

      final bounds = DetailTileAtlas.calculateVisibleBounds(
        const Size(100, 100),
        projection,
      );

      expect(bounds.minLat, equals(0.0));
      expect(bounds.maxLat, equals(0.0));
      expect(bounds.minLon, equals(0.0));
      expect(bounds.maxLon, equals(0.0));
    });

    test('calculateVisibleBounds computes normal visible bounding box', () {
      const projection = SphereProjection(
        center: Offset(100, 100),
        radius: 100.0,
        rotationX: 0.0,
        rotationZ: 0.0,
      );

      final bounds = DetailTileAtlas.calculateVisibleBounds(
        const Size(200, 200),
        projection,
      );

      // Verify that the bounds are computed and are reasonable
      expect(bounds.minLat, lessThan(bounds.maxLat));
      expect(bounds.minLon, lessThan(bounds.maxLon));
      // Max lat/lon shouldn't exceed earth geographic range in degrees
      expect(bounds.minLat, greaterThanOrEqualTo(-90.0));
      expect(bounds.maxLat, lessThanOrEqualTo(90.0));
      expect(bounds.minLon, greaterThanOrEqualTo(-180.0));
      expect(bounds.maxLon, lessThanOrEqualTo(180.0));
    });

    test('calculateVisibleBounds handles rotation centered around prime meridian', () {
      const projection = SphereProjection(
        center: Offset(100, 100),
        radius: 100.0,
        rotationX: 0.0,
        rotationZ: 0.0, // Longitude 0
      );

      final bounds = DetailTileAtlas.calculateVisibleBounds(
        const Size(200, 200),
        projection,
      );

      // Centered at 0 longitude, minLon should be negative, maxLon positive
      expect(bounds.minLon, lessThan(0.0));
      expect(bounds.maxLon, greaterThan(0.0));
    });
  });
}
