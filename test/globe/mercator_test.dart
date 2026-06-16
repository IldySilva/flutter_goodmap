import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/globe/mercator.dart';

void main() {
  group('Mercator Coordinate Math', () {
    test('latLngToMercator and mercatorToLatLng round-trip correctly', () {
      final inputs = [
        const LatLng(0, 0),
        const LatLng(45, 45),
        const LatLng(-60, 120),
        const LatLng(85, -150),
        const LatLng(-85, 10),
      ];

      for (final ll in inputs) {
        final mc = latLngToMercator(ll);
        final roundTrip = mercatorToLatLng(mc);

        expect(roundTrip.latitude, closeTo(ll.latitude, 1e-4));
        expect(roundTrip.longitude, closeTo(ll.longitude, 1e-4));
      }
    });

    test('tileMercatorBounds ranges match zoom sizes', () {
      // Zoom 0: tile 0,0 covers [0,0] to [1,1]
      final z0 = tileMercatorBounds(const TileId(0, 0, 0));
      expect(z0.minX, 0.0);
      expect(z0.minY, 0.0);
      expect(z0.maxX, 1.0);
      expect(z0.maxY, 1.0);

      // Zoom 1: tile 1,1 covers [0.5, 0.5] to [1,1]
      final z1 = tileMercatorBounds(const TileId(1, 1, 1));
      expect(z1.minX, 0.5);
      expect(z1.minY, 0.5);
      expect(z1.maxX, 1.0);
      expect(z1.maxY, 1.0);
    });

    test('tileLatLngBounds computes correct northwest/southeast corners', () {
      final bounds = tileLatLngBounds(const TileId(0, 0, 0));
      expect(bounds.northeast.latitude, closeTo(85.0511, 1e-2));
      final neLng = bounds.northeast.longitude;
      expect(neLng == 180.0 || neLng == -180.0 || (neLng - 180.0).abs() < 1e-2 || (neLng + 180.0).abs() < 1e-2, isTrue);
      expect(bounds.southwest.latitude, closeTo(-85.0511, 1e-2));
      expect(bounds.southwest.longitude, closeTo(-180.0, 1e-2));
    });
  });

  group('World tiles', () {
    test('worldTiles(z) returns 2^z x 2^z tiles all at zoom z', () {
      final z2 = worldTiles(2);
      expect(z2.length, 16);
      expect(z2.every((t) => t.z == 2), isTrue);
      expect(z2.toSet().length, 16); // all unique
    });
  });
}
