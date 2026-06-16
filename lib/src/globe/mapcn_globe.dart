import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'sphere_projection.dart';
import 'sphere_shader_painter.dart';
import 'tile_atlas.dart';

/// A theme-aware native 3D globe, rendered with a `ui.FragmentProgram` sphere
/// shader (no flutter_gpu). Drag to rotate, pinch to zoom. The basemap follows
/// the host `Theme`'s brightness (CARTO light/dark raster tiles).
class MapcnGlobe extends StatefulWidget {
  const MapcnGlobe({
    required this.initialCenter,
    this.initialZoom = 1,
    this.onCameraChanged,
    this.onTap,
    this.renderEnabled = true,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;

  /// Called whenever the camera centre changes (drag/zoom).
  final void Function(LatLng center)? onCameraChanged;

  /// Called with the geographic coordinate under a tap, or null off-globe.
  final void Function(LatLng? coordinate)? onTap;

  /// When false (tests), the GPU shader/atlas are skipped.
  final bool renderEnabled;

  @override
  State<MapcnGlobe> createState() => _MapcnGlobeState();
}

class _MapcnGlobeState extends State<MapcnGlobe> {
  final SphereShaderManager _shaderManager = SphereShaderManager();

  double _rotationX = 0; // latitude facing viewer (radians)
  double _rotationZ = 0; // longitude facing viewer (radians)
  double _zoom = 1;

  ui.Image? _atlas;
  ui.FragmentShader? _shader;
  TileAtlas? _atlasBuilder;
  Brightness? _brightness;

  double _baseZoom = 1;
  Offset _lastFocal = Offset.zero;
  Size _lastSize = Size.zero;

  static const double _maxLatRad = 85 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    _rotationX = widget.initialCenter.latitude * math.pi / 180.0;
    _rotationZ = widget.initialCenter.longitude * math.pi / 180.0;
    _zoom = widget.initialZoom;
    if (widget.renderEnabled) {
      _shaderManager.load().then((ok) {
        if (ok && mounted) _rebuildShader();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.renderEnabled) return;
    final b = Theme.of(context).brightness;
    if (_brightness != b) {
      _brightness = b;
      _rebuildAtlas(b);
    }
  }

  Future<void> _rebuildAtlas(Brightness brightness) async {
    _atlasBuilder?.dispose();
    final builder = TileAtlas(brightness: brightness);
    _atlasBuilder = builder;
    final img = await builder.build();
    if (!mounted || img == null) return;
    _atlas?.dispose();
    _atlas = img;
    _rebuildShader();
  }

  void _rebuildShader() {
    final img = _atlas;
    if (img == null || !_shaderManager.isReady) return;
    _shader = _shaderManager.createShader(img);
    if (mounted) setState(() {});
  }

  void _onScaleStart(ScaleStartDetails d) {
    _baseZoom = _zoom;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    // Slower, more precise rotation as you zoom in.
    final sensitivity = 0.005 / math.pow(2.0, _zoom - 1.0);
    setState(() {
      _rotationZ -= delta.dx * sensitivity;
      _rotationX =
          (_rotationX + delta.dy * sensitivity).clamp(-_maxLatRad, _maxLatRad);
      if (d.scale != 1.0) {
        _zoom = (_baseZoom + math.log(d.scale) / math.ln2).clamp(0.0, 6.0);
      }
    });
    widget.onCameraChanged?.call(_center);
  }

  void _onTapUp(TapUpDetails d) {
    final cb = widget.onTap;
    if (cb == null) return;
    final size = _lastSize;
    if (size.isEmpty) return;
    final shortSide = math.min(size.width, size.height);
    final proj = SphereProjection(
      center: Offset(size.width / 2, size.height / 2),
      radius: globeRadius(_zoom, shortSide),
      rotationX: _rotationX,
      rotationZ: _rotationZ,
    );
    cb(proj.unproject(d.localPosition));
  }

  LatLng get _center =>
      LatLng(_rotationX * 180 / math.pi, _rotationZ * 180 / math.pi);

  @override
  void dispose() {
    _atlasBuilder?.dispose();
    _atlas?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onTapUp: _onTapUp,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          final shader = _shader;
          if (!widget.renderEnabled || shader == null) {
            // Loading / test placeholder.
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const SizedBox.expand(),
            );
          }
          final shortSide = math.min(_lastSize.width, _lastSize.height);
          return CustomPaint(
            size: Size.infinite,
            painter: SphereShaderPainter(
              shader: shader,
              center: Offset(_lastSize.width / 2, _lastSize.height / 2),
              radius: globeRadius(_zoom, shortSide),
              rotationX: _rotationX,
              rotationZ: _rotationZ,
            ),
          );
        },
      ),
    );
  }
}
