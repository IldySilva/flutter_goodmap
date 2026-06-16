// Phase 0 device spike for MapcnGlobe.
// Run with:  flutter run -t lib/globe_spike.dart
//
// Renders the UV sphere textured with a procedural lat/lng grid, driven by a
// Ticker, presented via gpu.Texture.asImage(). Drag to rotate.
// GO = a textured sphere appears and rotates smoothly with no GPU errors.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:mapcn_flutter/mapcn.dart' show LatLng;
import 'package:mapcn_flutter/src/globe/globe_camera.dart';
import 'package:mapcn_flutter/src/globe/globe_renderer.dart';

void main() => runApp(const GlobeSpikeApp());

class GlobeSpikeApp extends StatelessWidget {
  const GlobeSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF101418),
          body: SafeArea(child: GlobeSpike()),
        ),
      );
}

class GlobeSpike extends StatefulWidget {
  const GlobeSpike({super.key});

  @override
  State<GlobeSpike> createState() => _GlobeSpikeState();
}

class _GlobeSpikeState extends State<GlobeSpike>
    with SingleTickerProviderStateMixin {
  final GlobeRenderer _renderer = GlobeRenderer();
  GlobeCamera _cam = const GlobeCamera(center: LatLng(0, 0), zoom: 2);
  ui.Image? _frame;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
    _renderer.setAtlasPixels(_gridRgba(1024, 512), 1024, 512);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    final logical = context.size ?? const Size(400, 400);
    final w = logical.width.toInt().clamp(1, 4096);
    final h = logical.height.toInt().clamp(1, 4096);
    final target = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      w,
      h,
    );
    _renderer.render(target, _cam.viewProjection(Size(w.toDouble(), h.toDouble())));
    if (mounted) setState(() => _frame = target.asImage());
  }

  void _onPan(DragUpdateDetails d) {
    setState(() {
      _cam = _cam.copyWith(
        center: LatLng(
          (_cam.center.latitude + d.delta.dy * 0.3).clamp(-89.0, 89.0),
          _cam.center.longitude - d.delta.dx * 0.3,
        ),
      );
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPan,
      child: CustomPaint(
        painter: _FramePainter(_frame),
        size: Size.infinite,
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image);

  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: img,
      fit: BoxFit.contain,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.image != image;
}

/// A procedural equirectangular grid so the sphere shows a recognizable texture
/// (lat/lng lines) without needing a bundled world image.
Uint8List _gridRgba(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final line = (x % 32 == 0) || (y % 32 == 0);
      px[i] = line ? 40 : 220; // R
      px[i + 1] = line ? 120 : 232; // G
      px[i + 2] = line ? 200 : 245; // B
      px[i + 3] = 255; // A
    }
  }
  return px;
}
