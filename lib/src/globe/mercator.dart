import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart' show LatLng, LatLngBounds;

/// Normalized Web-Mercator coordinate, X and Y in [0, 1]; (0,0) = top-left.
class MercatorCoordinate {
  const MercatorCoordinate(this.x, this.y);
  final double x;
  final double y;

  @override
  String toString() => 'MercatorCoordinate($x, $y)';
}

/// Bounding box of a tile in normalized Mercator coordinates.
class MercatorBounds {
  const MercatorBounds(this.minX, this.minY, this.maxX, this.maxY);
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

/// Identifier for an XYZ map tile.
class TileId {
  const TileId(this.z, this.x, this.y);
  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileId && z == other.z && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'TileId($z, $x, $y)';
}

/// [LatLng] -> normalized [MercatorCoordinate].
MercatorCoordinate latLngToMercator(LatLng ll) {
  final x = (ll.longitude + 180.0) / 360.0;
  final latRad = ll.latitude * math.pi / 180.0;
  final sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
  final y = 0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi);
  return MercatorCoordinate(x, y);
}

/// Normalized [MercatorCoordinate] -> [LatLng].
LatLng mercatorToLatLng(MercatorCoordinate mc) {
  final lng = mc.x * 360.0 - 180.0;
  final yClamped = (0.5 - mc.y) * 2.0 * math.pi;
  final exp2Y = math.exp(2.0 * yClamped);
  final sinLat = (exp2Y - 1.0) / (exp2Y + 1.0);
  final lat = math.asin(sinLat) * 180.0 / math.pi;
  return LatLng(lat, lng);
}

/// Mercator bounds of a tile.
MercatorBounds tileMercatorBounds(TileId tile) {
  final size = 1.0 / (1 << tile.z);
  final minX = tile.x * size;
  final minY = tile.y * size;
  return MercatorBounds(minX, minY, minX + size, minY + size);
}

/// Geographic bounds of a tile.
LatLngBounds tileLatLngBounds(TileId tile) {
  final mb = tileMercatorBounds(tile);
  final nw = mercatorToLatLng(MercatorCoordinate(mb.minX, mb.minY));
  final se = mercatorToLatLng(MercatorCoordinate(mb.maxX, mb.maxY));
  return LatLngBounds(
    southwest: LatLng(se.latitude, nw.longitude),
    northeast: LatLng(nw.latitude, se.longitude),
  );
}

/// All tiles covering the whole world at zoom [z] (2^z x 2^z).
List<TileId> worldTiles(int z) {
  final n = 1 << z;
  return [for (var x = 0; x < n; x++) for (var y = 0; y < n; y++) TileId(z, x, y)];
}
