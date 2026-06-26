import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../good_map.dart';
import '../heatmap/heatmap.dart';
import '../markers/marker.dart';
import '../popups/popup.dart';
import 'globe_overlays.dart';
import 'good_globe.dart';

/// A globe that becomes a street map when you zoom in.
///
/// Shows a [GoodGlobe] (world/regional view, with arcs + points) at low zoom,
/// then cross-fades to the native [GoodMap] — full vector streets and cities —
/// once you pinch past [globeZoomToFlat]. Zooming the flat map back out below
/// [flatZoomToGlobe] returns to the globe. The centre coordinate carries across.
class GoodMapGlobe extends StatefulWidget {
  const GoodMapGlobe({
    required this.initialCenter,
    this.initialZoom = 1.0,
    this.markers = const [],
    @Deprecated('Use markers instead') this.points = const [],
    this.popups = const [],
    this.arcs = const [],
    this.heatmaps = const [],
    this.atmosphere = false,
    this.controls = const GoodControls(),
    this.globeZoomToFlat = 3.5,
    this.flatZoomToGlobe = 4.0,
    this.flatEntryZoom = 5.0,
    this.globeEntryZoom = 3.0,
    this.transition = const Duration(milliseconds: 280),
    this.onTap,
    this.onSurfaceChanged,
    this.showDottedGrid = false,
    this.dottedGridColor,
    this.dottedGridRadius = 1.2,
    this.dateTime,
    this.sunPosition,
    this.timeRange,
    super.key,
  });

  final LatLng initialCenter;

  /// Initial globe zoom (0 = far, ~6 = close).
  final double initialZoom;

  /// Custom markers (widgets, assets, or fallback dots) plotted on the map and globe.
  final List<MarkerOptions> markers;

  /// Labelled points plotted on the globe.
  @Deprecated('Use markers instead')
  final List<GlobePoint> points;

  /// Declarative popups on the map and globe.
  final List<PopupOptions> popups;

  final List<GlobeArc> arcs;

  /// Heatmap layers rendered on the globe canvas.
  final List<HeatmapOptions> heatmaps;

  final bool atmosphere;
  final GoodControls controls;

  /// Globe zoom at which it hands off to the flat map.
  final double globeZoomToFlat;

  /// Flat-map zoom below which it hands back to the globe.
  final double flatZoomToGlobe;

  /// Flat-map zoom the map mounts at when entering from the globe.
  final double flatEntryZoom;

  /// Globe zoom the globe mounts at when returning from the flat map.
  final double globeEntryZoom;

  final Duration transition;

  /// Tapped coordinate on the globe surface (globe mode only).
  final void Function(LatLng? coordinate)? onTap;

  /// Called when the surface flips (true = flat map, false = globe).
  final void Function(bool isFlat)? onSurfaceChanged;

  /// When true, draws the dotted world landmass grid on the globe surface.
  final bool showDottedGrid;

  /// Colour of the dotted grid dots.
  final Color? dottedGridColor;

  /// Radius of each dot on the globe. Default: 1.2.
  final double dottedGridRadius;

  /// Enables the day/night terminator on the globe surface.
  final DateTime? dateTime;

  /// Explicit subsolar point (lat/lng) for the day/night terminator.
  final LatLng? sunPosition;

  /// Time range `(start, end)` to filter markers and arcs on the globe.
  final (double, double)? timeRange;

  @override
  State<GoodMapGlobe> createState() => _GoodMapGlobeState();
}

class _GoodMapGlobeState extends State<GoodMapGlobe> {
  late LatLng _center = widget.initialCenter;
  late double _globeStartZoom = widget.initialZoom;
  bool _flat = false;

  void _setFlat(bool flat) {
    if (_flat == flat) return;
    setState(() => _flat = flat);
    widget.onSurfaceChanged?.call(flat);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child =
        _flat
            ? GoodMap(
              key: const ValueKey('flat'),
              initialCenter: _center,
              initialZoom: widget.flatEntryZoom,
              controls: widget.controls,
              markers: widget.markers,
              popups: widget.popups,
              onCameraChanged: (pos) {
                _center = pos.target;
                if (pos.zoom < widget.flatZoomToGlobe) {
                  _globeStartZoom = widget.globeEntryZoom;
                  _setFlat(false);
                }
              },
            )
            : GoodGlobe(
              key: const ValueKey('globe'),
              initialCenter: _center,
              initialZoom: _globeStartZoom,
              markers: widget.markers,
              points: widget.points,
              popups: widget.popups,
              arcs: widget.arcs,
              heatmaps: widget.heatmaps,
              atmosphere: widget.atmosphere,
              onTap: widget.onTap,
              showDottedGrid: widget.showDottedGrid,
              dottedGridColor: widget.dottedGridColor,
              dottedGridRadius: widget.dottedGridRadius,
              dateTime: widget.dateTime,
              sunPosition: widget.sunPosition,
              timeRange: widget.timeRange,
              onCameraChanged: (center, zoom) {
                _center = center;
                if (zoom >= widget.globeZoomToFlat) _setFlat(true);
              },
            );

    return AnimatedSwitcher(duration: widget.transition, child: child);
  }
}
