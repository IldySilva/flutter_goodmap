// lib/src/globe/detail_tile_atlas.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'mercator.dart';
import 'sphere_projection.dart';

/// Describes the bounds and detail texture of a windowed LOD region.
class DetailBounds {
  const DetailBounds({
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
  });

  final double minLon;
  final double maxLon;
  final double minLat;
  final double maxLat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailBounds &&
          runtimeType == other.runtimeType &&
          minLon == other.minLon &&
          maxLon == other.maxLon &&
          minLat == other.minLat &&
          maxLat == other.maxLat;

  @override
  int get hashCode =>
      minLon.hashCode ^ maxLon.hashCode ^ minLat.hashCode ^ maxLat.hashCode;
}

/// Builds a high-resolution detail [ui.Image] atlas for a visible sub-region on the globe.
class DetailTileAtlas {
  DetailTileAtlas({
    required this.brightness,
    required this.center,
    required this.zoom,
    required this.viewportSize,
    required this.projection,
    this.width = 1024,
    this.height = 1024,
  });

  final Brightness brightness;
  final LatLng center;
  final double zoom;
  final Size viewportSize;
  final SphereProjection projection;
  final int width;
  final int height;

  static const int _tileSize = 256;
  final http.Client _client = http.Client();
  bool _disposed = false;


  /// Static helper to calculate the visible bounding box of viewport by grid sampling.
  static ({double minLat, double maxLat, double minLon, double maxLon})
      calculateVisibleBounds(Size viewportSize, SphereProjection projection) {
    final visibleCoords = <LatLng>[];
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      final y = viewportSize.height * i / steps;
      for (var j = 0; j <= steps; j++) {
        final x = viewportSize.width * j / steps;
        final latLng = projection.unproject(Offset(x, y));
        if (latLng != null) {
          visibleCoords.add(latLng);
        }
      }
    }

    if (visibleCoords.isEmpty) {
      return (minLat: 0.0, maxLat: 0.0, minLon: 0.0, maxLon: 0.0);
    }

    final double minLat = visibleCoords.map((c) => c.latitude).reduce(math.min);
    final double maxLat = visibleCoords.map((c) => c.latitude).reduce(math.max);

    double minLon, maxLon;
    if (visibleCoords.length == 1) {
      minLon = visibleCoords.first.longitude;
      maxLon = visibleCoords.first.longitude;
    } else {
      final lons = visibleCoords.map((c) => c.longitude).toList()..sort();
      var maxGap = 0.0;
      var gapIndex = 0;
      for (var i = 0; i < lons.length; i++) {
        final next = lons[(i + 1) % lons.length];
        var gap = next - lons[i];
        if (gap < 0) gap += 360;
        if (gap > maxGap) {
          maxGap = gap;
          gapIndex = i;
        }
      }
      minLon = lons[(gapIndex + 1) % lons.length];
      maxLon = lons[gapIndex];
      if (maxLon < minLon) {
        maxLon += 360;
      }
    }

    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }

  /// Calculates visible bounds, fetches local tiles, reprojects, and returns
  /// the detail atlas image and its boundaries. Returns null on failure.
  Future<({ui.Image image, DetailBounds bounds})?> build() async {
    final bounds = calculateVisibleBounds(viewportSize, projection);
    if (bounds.minLat == 0.0 && bounds.maxLat == 0.0 && bounds.minLon == 0.0 && bounds.maxLon == 0.0) {
      return null;
    }
    final minLat = bounds.minLat;
    final maxLat = bounds.maxLat;
    final minLon = bounds.minLon;
    final maxLon = bounds.maxLon;

    // 2. Determine appropriate tile zoom level
    final detailTileZoom = (zoom + 3.0).floor().clamp(5, 12);
    final n = 1 << detailTileZoom;

    // 3. Find tiles covering the bounding box
    final y1 = latLngToMercator(LatLng(maxLat, 0)).y;
    final y2 = latLngToMercator(LatLng(minLat, 0)).y;
    final minY = (y1 * n).floor().clamp(0, n - 1);
    final maxY = (y2 * n).floor().clamp(0, n - 1);

    final x1 = (minLon + 180.0) / 360.0 * n;
    final x2 = (maxLon + 180.0) / 360.0 * n;
    final minX = x1.floor();
    final maxX = x2.floor();

    final tiles = <TileId>[];
    for (var tx = minX; tx <= maxX; tx++) {
      final wrappedX = (tx % n + n) % n;
      for (var ty = minY; ty <= maxY; ty++) {
        tiles.add(TileId(detailTileZoom, wrappedX, ty));
      }
    }

    // Safety check: if visible area is too large, skip high-res Detail loading to avoid jank/rate limits.
    if (tiles.isEmpty || tiles.length > 36) return null;

    final numTilesX = maxX - minX + 1;
    final numTilesY = maxY - minY + 1;
    final mosaicWidth = numTilesX * _tileSize;
    final mosaicHeight = numTilesY * _tileSize;
    final mosaic = Uint8List(mosaicWidth * mosaicHeight * 4);

    var anyTile = false;
    const concurrency = 8;
    for (var i = 0; i < tiles.length; i += concurrency) {
      if (_disposed) return null;
      final batch = tiles.sublist(i, math.min(i + concurrency, tiles.length));
      await Future.wait([
        for (final tile in batch)
          _fetchTile(tile).then((px) {
            if (px == null) return;
            anyTile = true;
            var localX = -1;
            for (var tx = minX; tx <= maxX; tx++) {
              if ((tx % n + n) % n == tile.x) {
                localX = tx - minX;
                break;
              }
            }
            final localY = tile.y - minY;
            if (localX >= 0 && localY >= 0) {
              _blitTile(mosaic, mosaicWidth, localX, localY, px);
            }
          }),
      ]);
    }

    if (_disposed || !anyTile) return null;

    // Geographic bounds of the local mosaic
    final minMercX = minX / n;
    final maxMercX = (maxX + 1) / n;
    final minMercY = minY / n;
    final maxMercY = (maxY + 1) / n;

    final nw = mercatorToLatLng(MercatorCoordinate(minMercX, minMercY));
    final se = mercatorToLatLng(MercatorCoordinate(maxMercX, maxMercY));

    // Define continuous bounds for detail shader matching
    final detailBounds = DetailBounds(
      minLon: minLon * math.pi / 180.0,
      maxLon: maxLon * math.pi / 180.0,
      minLat: se.latitude * math.pi / 180.0,
      maxLat: nw.latitude * math.pi / 180.0,
    );

    final atlas = await compute(
      _reprojectToEquirectDetail,
      _ReprojectDetailArgs(
        mosaic,
        mosaicWidth,
        mosaicHeight,
        minMercX,
        maxMercX,
        minMercY,
        maxMercY,
        detailBounds.minLon,
        detailBounds.maxLon,
        detailBounds.minLat,
        detailBounds.maxLat,
        width,
        height,
      ),
    );

    if (_disposed) return null;
    final img = await _decode(atlas, width, height);
    if (img == null) return null;

    return (image: img, bounds: detailBounds);
  }

  String _styleName() =>
      brightness == Brightness.dark ? 'dark_nolabels' : 'light_nolabels';

  Future<Uint8List?> _fetchTile(TileId tile) async {
    try {
      final url =
          'https://basemaps.cartocdn.com/${_styleName()}/${tile.z}/${tile.x}/${tile.y}.png';
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  void _blitTile(
      Uint8List mosaic, int mosaicWidth, int localX, int localY, Uint8List px) {
    final ox = localX * _tileSize;
    final oy = localY * _tileSize;
    for (var y = 0; y < _tileSize; y++) {
      final srcRow = y * _tileSize * 4;
      final dstRow = ((oy + y) * mosaicWidth + ox) * 4;
      mosaic.setRange(dstRow, dstRow + _tileSize * 4, px, srcRow);
    }
  }

  Future<ui.Image?> _decode(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, (img) {
      completer.complete(img);
    });
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _client.close();
  }
}

class _ReprojectDetailArgs {
  const _ReprojectDetailArgs(
    this.mosaic,
    this.mosaicWidth,
    this.mosaicHeight,
    this.minMercX,
    this.maxMercX,
    this.minMercY,
    this.maxMercY,
    this.minLonRad,
    this.maxLonRad,
    this.minLatRad,
    this.maxLatRad,
    this.width,
    this.height,
  );

  final Uint8List mosaic;
  final int mosaicWidth;
  final int mosaicHeight;
  final double minMercX;
  final double maxMercX;
  final double minMercY;
  final double maxMercY;
  final double minLonRad;
  final double maxLonRad;
  final double minLatRad;
  final double maxLatRad;
  final int width;
  final int height;
}

/// Reprojects the Mercator local mosaic segment into an equirectangular detail image.
Uint8List _reprojectToEquirectDetail(_ReprojectDetailArgs args) {
  final mosaic = args.mosaic;
  final mosaicWidth = args.mosaicWidth;
  final mosaicHeight = args.mosaicHeight;
  final minMercX = args.minMercX;
  final minMercY = args.minMercY;
  final minLonRad = args.minLonRad;
  final maxLonRad = args.maxLonRad;
  final minLatRad = args.minLatRad;
  final maxLatRad = args.maxLatRad;
  final width = args.width;
  final height = args.height;

  final out = Uint8List(width * height * 4);

  final minLon = minLonRad * 180.0 / math.pi;
  final maxLon = maxLonRad * 180.0 / math.pi;
  final minLat = minLatRad * 180.0 / math.pi;
  final maxLat = maxLatRad * 180.0 / math.pi;

  for (var ay = 0; ay < height; ay++) {
    final lat = maxLat - (maxLat - minLat) * (ay + 0.5) / height;
    for (var ax = 0; ax < width; ax++) {
      final lon = minLon + (maxLon - minLon) * (ax + 0.5) / width;
      final normalizedLon = ((lon + 180.0) % 360.0 + 360.0) % 360.0 - 180.0;
      final mc = latLngToMercator(LatLng(lat, normalizedLon));

      var mx = mc.x;
      if (mx < minMercX) {
        mx += 1.0;
      }

      final sx = ((mx - minMercX) * mosaicWidth).floor().clamp(0, mosaicWidth - 1);
      final sy = ((mc.y - minMercY) * mosaicHeight).floor().clamp(0, mosaicHeight - 1);

      final src = (sy * mosaicWidth + sx) * 4;
      final dst = (ay * width + ax) * 4;
      out[dst] = mosaic[src];
      out[dst + 1] = mosaic[src + 1];
      out[dst + 2] = mosaic[src + 2];
      out[dst + 3] = 255;
    }
  }

  return out;
}
