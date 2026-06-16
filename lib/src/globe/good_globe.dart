import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'globe_overlays.dart';
import 'sphere_projection.dart';
import 'sphere_shader_painter.dart';
import 'tile_atlas.dart';

/// A theme-aware native 3D globe, rendered with a `ui.FragmentProgram` sphere
/// shader (no flutter_gpu). Drag to rotate (with inertia), pinch to zoom. The
/// basemap follows the host `Theme`'s brightness (CARTO light/dark raster tiles).
class GoodGlobe extends StatefulWidget {
  const GoodGlobe({
    required this.initialCenter,
    this.initialZoom = 1,
    this.points = const [],
    this.arcs = const [],
    this.atmosphere = false,
    this.atmosphereColor,
    this.onCameraChanged,
    this.onTap,
    this.onPointTap,
    super.key,
    this.renderEnabled = true,
  });

  final LatLng initialCenter;
  final double initialZoom;

  /// Labelled points plotted on the globe.
  final List<GlobePoint> points;

  /// Great-circle arcs drawn between coordinates.
  final List<GlobeArc> arcs;

  /// Draws a soft atmospheric glow ring around the globe. Off by default.
  final bool atmosphere;

  /// Atmosphere colour; defaults to the theme's primary colour.
  final Color? atmosphereColor;

  /// Called whenever the camera centre changes (drag/zoom/inertia).
  final void Function(LatLng center)? onCameraChanged;

  /// Called with the geographic coordinate under a tap, or null off-globe.
  final void Function(LatLng? coordinate)? onTap;

  /// Called when a [GlobePoint] is tapped. The globe also shows a small popup
  /// card for the tapped point automatically.
  final void Function(GlobePoint point)? onPointTap;

  /// When false (tests), GPU shader/atlas and the inertia ticker are skipped.
  final bool renderEnabled;

  @override
  State<GoodGlobe> createState() => _GoodGlobeState();
}

class _GoodGlobeState extends State<GoodGlobe>
    with TickerProviderStateMixin {
  final SphereShaderManager _shaderManager = SphereShaderManager();

  // Drives marching-dash animation on arcs.
  late final AnimationController _dash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  GlobePoint? _selectedPoint;

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

  // Inertia: angular velocity in radians/second, decayed by a Ticker.
  late final Ticker _ticker = createTicker(_onTick);
  double _angVelX = 0;
  double _angVelZ = 0;
  double? _lastTickSeconds;

  static const double _maxLatRad = 85 * math.pi / 180;
  static const double _frictionTau = 0.4; // larger = longer glide

  double _sensitivity() => 0.005 / math.pow(2.0, _zoom - 1.0);

  @override
  void initState() {
    super.initState();
    _rotationX = widget.initialCenter.latitude * math.pi / 180.0;
    _rotationZ = widget.initialCenter.longitude * math.pi / 180.0;
    _zoom = widget.initialZoom;
    if (widget.renderEnabled) {
      if (widget.arcs.isNotEmpty) _dash.repeat();
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

  // --- Gestures + inertia --------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _stopInertia();
    _baseZoom = _zoom;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    final s = _sensitivity();
    setState(() {
      _rotationZ -= delta.dx * s;
      _rotationX = (_rotationX + delta.dy * s).clamp(-_maxLatRad, _maxLatRad);
      if (d.scale != 1.0) {
        _zoom = (_baseZoom + math.log(d.scale) / math.ln2).clamp(0.0, 6.0);
      }
    });
    widget.onCameraChanged?.call(_center);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!widget.renderEnabled) return; // no ticker in tests
    final v = d.velocity.pixelsPerSecond;
    final s = _sensitivity();
    _angVelZ = v.dx * s;
    _angVelX = v.dy * s;
    if (_angVelX.abs() > 0.05 || _angVelZ.abs() > 0.05) {
      _lastTickSeconds = null;
      if (!_ticker.isActive) _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = _lastTickSeconds == null ? 0.016 : now - _lastTickSeconds!;
    _lastTickSeconds = now;
    if (dt <= 0) return;

    _rotationZ -= _angVelZ * dt;
    _rotationX = (_rotationX + _angVelX * dt).clamp(-_maxLatRad, _maxLatRad);

    final decay = math.exp(-dt / _frictionTau);
    _angVelZ *= decay;
    _angVelX *= decay;

    setState(() {});
    widget.onCameraChanged?.call(_center);

    if (_angVelX.abs() < 0.01 && _angVelZ.abs() < 0.01) _stopInertia();
  }

  void _stopInertia() {
    _angVelX = 0;
    _angVelZ = 0;
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTapUp(TapUpDetails d) {
    final size = _lastSize;
    if (size.isEmpty) return;
    final shortSide = math.min(size.width, size.height);
    final proj = SphereProjection(
      center: Offset(size.width / 2, size.height / 2),
      radius: globeRadius(_zoom, shortSide),
      rotationX: _rotationX,
      rotationZ: _rotationZ,
    );

    // Hit-test visible points first (within 22px of the projected dot).
    GlobePoint? hit;
    var best = 22.0;
    for (final p in widget.points) {
      final screen = proj.project(p.coordinate);
      if (screen == null) continue;
      final dist = (screen - d.localPosition).distance;
      if (dist < best) {
        best = dist;
        hit = p;
      }
    }

    setState(() => _selectedPoint = hit);
    if (hit != null) {
      widget.onPointTap?.call(hit);
    } else {
      widget.onTap?.call(proj.unproject(d.localPosition));
    }
  }

  LatLng get _center =>
      LatLng(_rotationX * 180 / math.pi, _rotationZ * 180 / math.pi);

  @override
  void dispose() {
    _dash.dispose();
    _ticker.dispose();
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
      onScaleEnd: _onScaleEnd,
      onTapUp: _onTapUp,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
          final shader = _shader;
          if (!widget.renderEnabled || shader == null) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const SizedBox.expand(),
            );
          }
          final shortSide = math.min(_lastSize.width, _lastSize.height);
          final center = Offset(_lastSize.width / 2, _lastSize.height / 2);
          final radius = globeRadius(_zoom, shortSide);
          final projection = SphereProjection(
            center: center,
            radius: radius,
            rotationX: _rotationX,
            rotationZ: _rotationZ,
          );
          final selected = _selectedPoint;
          final selectedScreen =
              selected == null ? null : projection.project(selected.coordinate);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.atmosphere)
                CustomPaint(
                  size: Size.infinite,
                  painter: AtmospherePainter(
                    center: center,
                    radius: radius,
                    color: widget.atmosphereColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                ),
              CustomPaint(
                size: Size.infinite,
                painter: SphereShaderPainter(
                  shader: shader,
                  center: center,
                  radius: radius,
                  rotationX: _rotationX,
                  rotationZ: _rotationZ,
                ),
              ),
              if (widget.arcs.isNotEmpty || widget.points.isNotEmpty)
                CustomPaint(
                  size: Size.infinite,
                  painter: GlobeOverlayPainter(
                    projection: projection,
                    arcs: widget.arcs,
                    points: widget.points,
                    dashAnimation: _dash,
                  ),
                ),
              // Popup card for a tapped point — follows it, hides when occluded.
              if (selected != null && selectedScreen != null)
                Positioned(
                  left: selectedScreen.dx - 90,
                  top: selectedScreen.dy - 56,
                  width: 180,
                  child: _PointPopup(
                    label: selected.label ?? 'Point',
                    onClose: () => setState(() => _selectedPoint = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Small card anchored above a tapped [GlobePoint].
class _PointPopup extends StatelessWidget {
  const _PointPopup({required this.label, required this.onClose});

  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
