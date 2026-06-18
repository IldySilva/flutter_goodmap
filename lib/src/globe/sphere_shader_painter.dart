import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      // Fallback for running inside the package itself (tests/example by path).
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
  });

  final ui.FragmentShader shader;
  final ui.Image baseAtlas;
  final ui.Image? detailAtlas;
  final DetailBounds? detailBounds;
  final Offset center;
  final double radius;
  final double rotationX;
  final double rotationZ;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || !radius.isFinite) return;
    if (!size.width.isFinite || !size.height.isFinite) return;

    var i = 0;
    shader.setFloat(i++, size.width);
    shader.setFloat(i++, size.height);
    shader.setFloat(i++, center.dx);
    shader.setFloat(i++, center.dy);
    shader.setFloat(i++, radius);
    shader.setFloat(i++, rotationX);
    shader.setFloat(i++, rotationZ);

    // Bind dynamic detail bounds float uniforms.
    final hasDetail = detailAtlas != null && detailBounds != null;
    shader.setFloat(i++, hasDetail ? detailBounds!.minLon : 0.0);
    shader.setFloat(i++, hasDetail ? detailBounds!.maxLon : 0.0);
    shader.setFloat(i++, hasDetail ? detailBounds!.minLat : 0.0);
    shader.setFloat(i++, hasDetail ? detailBounds!.maxLat : 0.0);
    shader.setFloat(i++, hasDetail ? 1.0 : 0.0);

    // Bind texture samplers:
    // Slot 0: base world atlas
    // Slot 1: detail high-res atlas (fallback to base atlas if none loaded to prevent GL crashes)
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
      old.rotationZ != rotationZ;
}
