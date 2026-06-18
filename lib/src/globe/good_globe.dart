import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../markers/marker.dart';
import '../popups/popup.dart';
import 'detail_tile_atlas.dart';
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
    this.markers = const [],
    @Deprecated('Use markers instead') this.points = const [],
    this.arcs = const [],
    this.popups = const [],
    this.atmosphere = false,
    this.atmosphereColor,
    this.onCameraChanged,
    this.onTap,
    this.onPointTap,
    super.key,
    @visibleForTesting this.renderEnabled = true,
  });

  final LatLng initialCenter;
  final double initialZoom;

  /// Labelled points plotted on the globe.
  @Deprecated('Use markers instead')
  final List<GlobePoint> points;

  /// Custom markers (widgets, assets, or fallback dots) plotted on the globe.
  final List<MarkerOptions> markers;

  /// Popups overlaying the globe.
  final List<PopupOptions> popups;

  /// Great-circle arcs drawn between coordinates.
  final List<GlobeArc> arcs;

  /// Draws a soft atmospheric glow ring around the globe. Off by default.
  final bool atmosphere;

  /// Atmosphere colour; defaults to the theme's primary colour.
  final Color? atmosphereColor;

  /// Called whenever the camera changes (drag/zoom/inertia), with the new
  /// centre and zoom.
  final void Function(LatLng center, double zoom)? onCameraChanged;

  /// Called with the geographic coordinate under a tap, or null off-globe.
  final void Function(LatLng? coordinate)? onTap;

  /// Called when a marker/point is tapped. The globe also shows a small popup
  /// card for the tapped point automatically.
  final void Function(MarkerOptions marker)? onPointTap;

  /// When false (tests), GPU shader/atlas and the inertia ticker are skipped.
  final bool renderEnabled;

  @override
  State<GoodGlobe> createState() => _GoodGlobeState();
}

class _GoodGlobeState extends State<GoodGlobe>
    with TickerProviderStateMixin {
  final SphereShaderManager _shaderManager = SphereShaderManager();

  // Drives marching-dash animation on arcs.
  late final AnimationController _dash;

  MarkerOptions? _selectedMarker;

  double _rotationX = 0; // latitude facing viewer (radians)
  double _rotationZ = 0; // longitude facing viewer (radians)
  double _zoom = 1;

  ui.Image? _atlas;
  ui.FragmentShader? _shader;
  TileAtlas? _atlasBuilder;
  Brightness? _brightness;

  // Windowed LOD details properties
  ui.Image? _detailAtlas;
  DetailBounds? _detailBounds;
  DetailTileAtlas? _detailBuilder;
  Timer? _lodDebounce;

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

  List<MarkerOptions> get _allMarkers => [
        ...widget.markers,
        ...widget.points,
      ];

  List<MarkerOptions> get _canvasMarkers => _allMarkers
      .where((m) => m.child == null && m.image == null)
      .toList();

  @override
  void initState() {
    super.initState();
    _dash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
      if (_detailAtlas != null) {
        _detailAtlas?.dispose();
        _detailAtlas = null;
        _detailBounds = null;
      }
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
    _scheduleLodDetails();
  }

  void _rebuildShader() {
    final img = _atlas;
    if (img == null || !_shaderManager.isReady) return;
    _shader = _shaderManager.createShader(img);
    if (mounted) setState(() {});
  }

  // --- Windowed LOD detail loader logic ------------------------------------

  void _resetLodDebounce() {
    _lodDebounce?.cancel();
    _lodDebounce = null;
  }

  void _scheduleLodDetails() {
    _resetLodDebounce();
    if (!widget.renderEnabled) return;
    if (_zoom <= 3.0) {
      if (_detailAtlas != null) {
        final oldAtlas = _detailAtlas;
        _detailAtlas = null;
        _detailBounds = null;
        _detailBuilder?.dispose();
        _detailBuilder = null;
        if (mounted) {
          setState(() {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldAtlas?.dispose();
        });
      }
      return;
    }

    _lodDebounce = Timer(const Duration(milliseconds: 250), () {
      _loadDetailAtlas();
    });
  }

  Future<void> _loadDetailAtlas() async {
    if (!mounted || !widget.renderEnabled) return;
    final brightness = _brightness;
    if (brightness == null) return;

    final size = _lastSize;
    if (size.isEmpty) return;
    final shortSide = math.min(size.width, size.height);
    final radius = globeRadius(_zoom, shortSide);
    final center = Offset(size.width / 2, size.height / 2);
    final projection = SphereProjection(
      center: center,
      radius: radius,
      rotationX: _rotationX,
      rotationZ: _rotationZ,
    );

    _detailBuilder?.dispose();

    final builder = DetailTileAtlas(
      brightness: brightness,
      center: _center,
      zoom: _zoom,
      viewportSize: size,
      projection: projection,
    );
    _detailBuilder = builder;

    final result = await builder.build();
    if (!mounted || _detailBuilder != builder || result == null) {
      if (result != null) {
        result.image.dispose();
      }
      return;
    }

    final oldAtlas = _detailAtlas;
    setState(() {
      _detailAtlas = result.image;
      _detailBounds = result.bounds;
    });

    if (oldAtlas != null && oldAtlas != _detailAtlas) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldAtlas.dispose();
      });
    }
  }

  // --- Gestures + inertia --------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _stopInertia();
    _resetLodDebounce();
    _baseZoom = _zoom;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    final s = _sensitivity();
    _resetLodDebounce();
    setState(() {
      _rotationZ -= delta.dx * s;
      _rotationX = (_rotationX + delta.dy * s).clamp(-_maxLatRad, _maxLatRad);
      if (d.scale != 1.0) {
        _zoom = (_baseZoom + math.log(d.scale) / math.ln2).clamp(0.0, 6.0);
      }
    });
    widget.onCameraChanged?.call(_center, _zoom);
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
    } else {
      _scheduleLodDetails();
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

    _resetLodDebounce();

    setState(() {});
    widget.onCameraChanged?.call(_center, _zoom);

    if (_angVelX.abs() < 0.01 && _angVelZ.abs() < 0.01) {
      _stopInertia();
      _scheduleLodDetails();
    }
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

    // Hit-test visible canvas points first (within 22px of the projected dot).
    MarkerOptions? hit;
    var best = 22.0;
    for (final p in _canvasMarkers) {
      final screen = proj.project(p.position);
      if (screen == null) continue;
      final dist = (screen - d.localPosition).distance;
      if (dist < best) {
        best = dist;
        hit = p;
      }
    }

    setState(() => _selectedMarker = hit);
    if (hit != null) {
      widget.onPointTap?.call(hit);
      hit.onTap?.call();
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
    _detailBuilder?.dispose();
    _detailAtlas?.dispose();
    _lodDebounce?.cancel();
    super.dispose();
  }

  Iterable<Widget> _buildMarkerOverlay(MarkerOptions marker, SphereProjection proj) {
    final screen = proj.project(marker.position);
    if (screen == null) return const [];
    return [
      Positioned(
        left: screen.dx,
        top: screen.dy,
        child: FractionalTranslation(
          translation: Offset(-(marker.alignment.x + 1) / 2, -(marker.alignment.y + 1) / 2),
          child: marker.onTap == null
              ? _markerChild(marker)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: marker.onTap,
                  child: _markerChild(marker),
                ),
        ),
      ),
    ];
  }

  Widget _markerChild(MarkerOptions marker) {
    if (marker.child != null) return marker.child!;
    final image = marker.image!;
    return Image.asset(
      image.assetName,
      width: image.size.width,
      height: image.size.height,
    );
  }

  Iterable<Widget> _buildPopupOverlay(PopupOptions popup, SphereProjection proj) {
    final screen = proj.project(popup.position);
    if (screen == null) return const [];
    return [
      Positioned(
        left: screen.dx,
        top: screen.dy,
        child: FractionalTranslation(
          translation: Offset(-(popup.alignment.x + 1) / 2, -(popup.alignment.y + 1) / 2),
          child: popup.child,
        ),
      ),
    ];
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
          final shortSide = math.min(_lastSize.width, _lastSize.height);
          final center = Offset(_lastSize.width / 2, _lastSize.height / 2);
          final radius = globeRadius(_zoom, shortSide);
          final projection = SphereProjection(
            center: center,
            radius: radius,
            rotationX: _rotationX,
            rotationZ: _rotationZ,
          );
          final canvasMarkers = _canvasMarkers;
          final allMarkers = _allMarkers;
          final selected = _selectedMarker;
          final selectedScreen =
              selected == null ? null : projection.project(selected.position);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (!widget.renderEnabled || shader == null)
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              if (widget.renderEnabled && widget.atmosphere)
                CustomPaint(
                  size: Size.infinite,
                  painter: AtmospherePainter(
                    center: center,
                    radius: radius,
                    color: widget.atmosphereColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                ),
              if (widget.renderEnabled && shader != null && _atlas != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: SphereShaderPainter(
                    shader: shader,
                    baseAtlas: _atlas!,
                    detailAtlas: _detailAtlas,
                    detailBounds: _detailBounds,
                    center: center,
                    radius: radius,
                    rotationX: _rotationX,
                    rotationZ: _rotationZ,
                  ),
                ),
              if (widget.arcs.isNotEmpty || canvasMarkers.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: GlobeOverlayPainter(
                      projection: projection,
                      arcs: widget.arcs,
                      markers: canvasMarkers,
                      dashAnimation: _dash,
                    ),
                  ),
                ),
              // Widget & image markers projected on the sphere:
              for (final marker in allMarkers)
                if (marker.child != null || marker.image != null)
                  ..._buildMarkerOverlay(marker, projection),

              // Declarative popups projected on the sphere:
              for (final popup in widget.popups)
                ..._buildPopupOverlay(popup, projection),

              // Popup card for a tapped point — follows it, hides when occluded.
              if (selected != null && selectedScreen != null && selected.label != null)
                Positioned(
                  left: selectedScreen.dx - 90,
                  top: selectedScreen.dy - 56,
                  width: 180,
                  child: _PointPopup(
                    label: selected.label!,
                    onClose: () => setState(() => _selectedMarker = null),
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
