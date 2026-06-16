import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'mercator.dart';

/// Builds a single equirectangular [ui.Image] atlas for the globe by fetching
/// CARTO raster tiles and reprojecting them from Web-Mercator to equirectangular
/// on the CPU. Theme-aware (light/dark). Runs once per (brightness, zoom).
class TileAtlas {
  TileAtlas({
    required this.brightness,
    this.tileZoom = 2,
    this.width = 1024,
    this.height = 512,
  });

  final Brightness brightness;
  final int tileZoom;
  final int width;
  final int height;

  static const int _tileSize = 256;
  final HttpClient _client = HttpClient();
  bool _disposed = false;

  /// Fetches tiles, reprojects, and returns the equirectangular atlas image.
  /// Returns null if it was disposed or every tile failed.
  Future<ui.Image?> build() async {
    final n = 1 << tileZoom;
    final mosaicSize = _tileSize * n;
    final mosaic = Uint8List(mosaicSize * mosaicSize * 4);

    var anyTile = false;
    await Future.wait([
      for (final tile in worldTiles(tileZoom))
        _fetchTile(tile).then((px) {
          if (px == null) return;
          anyTile = true;
          _blitTile(mosaic, mosaicSize, tile, px);
        }),
    ]);
    if (_disposed || !anyTile) return null;

    final atlas = _reproject(mosaic, mosaicSize);
    return _decode(atlas, width, height);
  }

  String _styleName() =>
      brightness == Brightness.dark ? 'dark_nolabels' : 'light_nolabels';

  Future<Uint8List?> _fetchTile(TileId tile) async {
    try {
      final url =
          'https://basemaps.cartocdn.com/${_styleName()}/${tile.z}/${tile.x}/${tile.y}.png';
      final request = await _client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // Copy a 256x256 tile's RGBA pixels into the mercator mosaic at its position.
  void _blitTile(Uint8List mosaic, int mosaicSize, TileId tile, Uint8List px) {
    final ox = tile.x * _tileSize;
    final oy = tile.y * _tileSize;
    for (var y = 0; y < _tileSize; y++) {
      final srcRow = y * _tileSize * 4;
      final dstRow = ((oy + y) * mosaicSize + ox) * 4;
      mosaic.setRange(dstRow, dstRow + _tileSize * 4, px, srcRow);
    }
  }

  // Inverse-sample the mercator mosaic into an equirectangular atlas.
  Uint8List _reproject(Uint8List mosaic, int mosaicSize) {
    final out = Uint8List(width * height * 4);
    for (var ay = 0; ay < height; ay++) {
      final lat = 90.0 - 180.0 * (ay + 0.5) / height;
      for (var ax = 0; ax < width; ax++) {
        final lng = -180.0 + 360.0 * (ax + 0.5) / width;
        final mc = latLngToMercator(LatLng(lat, lng));
        final sx = (mc.x * mosaicSize).floor().clamp(0, mosaicSize - 1);
        final sy = (mc.y * mosaicSize).floor().clamp(0, mosaicSize - 1);
        final src = (sy * mosaicSize + sx) * 4;
        final dst = (ay * width + ax) * 4;
        out[dst] = mosaic[src];
        out[dst + 1] = mosaic[src + 1];
        out[dst + 2] = mosaic[src + 2];
        out[dst + 3] = 255;
      }
    }
    return out;
  }

  Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _client.close(force: true);
  }
}
