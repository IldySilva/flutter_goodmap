// lib/src/globe/sphere_shader_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'detail_tile_atlas.dart';

/// Loads the sphere `FragmentProgram` and creates shader instances with the
/// equirectangular atlas bound. Uses the stable `ui.FragmentProgram` API — no
/// flutter_gpu, works on iOS, Android, web and desktop.
class SphereShaderManager {
  ui.FragmentProgram? _program;
  bool _loading = false;

  bool get isReady => _program != null;

  /// Loads the program once. Returns true on success.
  Future<bool> load() async {
    if (_program != null) return true;
    if (_loading) return false;
    _loading = true;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/goodmap/shaders/sphere.frag',
      );
      return true;
    } catch (e) {
      // Fallback for running inside the package itself (tests/example by path)
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/sphere.frag');
        return true;
      } catch (e2) {
        debugPrint('GoodGlobe: failed to load sphere shader: $e2');
        return false;
      }
    } finally {
      _loading = false;
    }
  }

  /// Creates a shader instance with [atlas] bound to the texture sampler.
  ui.FragmentShader? createShader(ui.Image atlas) {
    final program = _program;
    if (program == null) return null;
    final shader = program.fragmentShader();
    shader.setImageSampler(0, atlas);
    return shader;
  }
}

/// Draws the orthographic textured sphere by filling the canvas with the sphere
/// fragment shader.
class SphereShaderPainter extends CustomPainter {
  SphereShaderPainter({
    required this.shader,
    required this.baseAtlas,
    this.detailAtlas,
    this.detailBounds,
    required this.center,
    required this.radius,
    required this.rotationX,
    required this.rotationZ,
    this.sunDirection,
    this.enableDayNight = false,
  });

  final ui.FragmentShader shader;
  final ui.Image baseAtlas;
  final ui.Image? detailAtlas;
  final DetailBounds? detailBounds;
  final Offset center;
  final double radius;
  final double rotationX;
  final double rotationZ;

  /// Normalized sun direction vector in geographic (earth-centred) coordinates.
  /// Computed via [sunDirectionVector] from a subsolar [LatLng].
  final (double, double, double)? sunDirection;

  /// When true, the shader applies the day/night terminator based on [sunDirection].
  final bool enableDayNight;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || !radius.isFinite) return;
    if (!size.width.isFinite || !size.height.isFinite) return;

    var i = 0;
    shader.setFloat(i++, size.width);   // 0 uResolutionX
    shader.setFloat(i++, size.height);  // 1 uResolutionY
    shader.setFloat(i++, center.dx);    // 2 uCenterX
    shader.setFloat(i++, center.dy);    // 3 uCenterY
    shader.setFloat(i++, radius);       // 4 uRadius
    shader.setFloat(i++, rotationX);    // 5 uRotationX
    shader.setFloat(i++, rotationZ);    // 6 uRotationZ

    // Detail atlas bounds + flag.
    final hasDetail = detailAtlas != null && detailBounds != null;
    shader.setFloat(i++, hasDetail ? detailBounds!.minLon : 0.0); // 7
    shader.setFloat(i++, hasDetail ? detailBounds!.maxLon : 0.0); // 8
    shader.setFloat(i++, hasDetail ? detailBounds!.minLat : 0.0); // 9
    shader.setFloat(i++, hasDetail ? detailBounds!.maxLat : 0.0); // 10
    shader.setFloat(i++, hasDetail ? 1.0 : 0.0);                  // 11

    // Day/night terminator (indices 12-15).
    final dir =
        enableDayNight && sunDirection != null ? sunDirection! : (0.0, 0.0, 0.0);
    shader.setFloat(i++, dir.$1);                          // 12 uSunDirX
    shader.setFloat(i++, dir.$2);                          // 13 uSunDirY
    shader.setFloat(i++, dir.$3);                          // 14 uSunDirZ
    shader.setFloat(i++, enableDayNight ? 1.0 : 0.0);     // 15 uEnableDayNight

    // Texture samplers.
    shader.setImageSampler(0, baseAtlas);
    shader.setImageSampler(1, hasDetail ? detailAtlas! : baseAtlas);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(SphereShaderPainter old) =>
      old.shader != shader ||
      old.baseAtlas != baseAtlas ||
      old.detailAtlas != detailAtlas ||
      old.detailBounds != detailBounds ||
      old.center != center ||
      old.radius != radius ||
      old.rotationX != rotationX ||
      old.rotationZ != rotationZ ||
      old.sunDirection != sunDirection ||
      old.enableDayNight != enableDayNight;

  // ---------------------------------------------------------------------------
  // Static helpers for sun-position astronomy.
  // ---------------------------------------------------------------------------

  /// Computes the subsolar point (lat/lng in degrees where the sun is directly
  /// overhead) from a UTC [dateTime] using an approximate solar formula.
  ///
  /// Accuracy is ~1–2° which is sufficient for the visual terminator effect.
  static LatLng sunPositionFromDateTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    // Day of year (1-based).
    final startOfYear = DateTime.utc(utc.year);
    final dayOfYear = utc.difference(startOfYear).inDays + 1;

    // Solar declination (degrees): ranges ±23.45°, peaking at summer solstice.
    final declDeg =
        -23.45 * math.cos(2 * math.pi / 365.0 * (dayOfYear + 10));

    // Subsolar longitude: the sun is at longitude 0° at 12:00 UTC.
    final hourDecimal =
        utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    final subLng = (12.0 - hourDecimal) * 15.0;

    return LatLng(declDeg, subLng);
  }

  /// Converts a geographic subsolar point [sunPos] (latitude/longitude in
  /// degrees) to a normalized direction vector in earth-centred geographic
  /// coordinates suitable for the day/night shader uniforms.
  static (double, double, double) sunDirectionVector(LatLng sunPos) {
    final lat = sunPos.latitude * math.pi / 180;
    final lng = sunPos.longitude * math.pi / 180;
    return (
      math.cos(lat) * math.cos(lng), // X
      math.cos(lat) * math.sin(lng), // Y
      math.sin(lat),                 // Z
    );
  }
}
