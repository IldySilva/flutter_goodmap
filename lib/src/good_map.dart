// lib/src/good_map.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'controls/controls.dart';
import 'good_map_controller.dart';
import 'popups/popup_layer.dart';
import 'theme/basemaps.dart';
import 'theme/good_map_theme.dart';

export 'controls/controls.dart' show GoodControls;

/// Test seam: builds the native map view. Production uses [_defaultMapBuilder].
typedef GoodMapBuilder = Widget Function({
  required String styleString,
  required CameraPosition initialCameraPosition,
  required void Function(MapLibreMapController) onMapCreated,
  required void Function() onStyleLoaded,
  required void Function(CameraPosition) onCameraMove,
});

/// A theme-aware map with overlay markers/popups and zoom/compass controls.
class GoodMap extends StatefulWidget {
  const GoodMap({
    required this.initialCenter,
    this.onMapReady,
    this.onCameraChanged,
    this.initialZoom = 11,
    this.controls = const GoodControls(),
    this.theme,
    this.markers = const [],
    this.popups = const [],
    @visibleForTesting this.mapBuilder = _defaultMapBuilder,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final GoodControls controls;
  final GoodMapTheme? theme;
  final void Function(GoodMapController)? onMapReady;
  final List<MarkerOptions> markers;
  final List<PopupOptions> popups;

  /// Called on camera moves with the current position (target + zoom).
  final void Function(CameraPosition)? onCameraChanged;
  final GoodMapBuilder mapBuilder;

  @override
  State<GoodMap> createState() => _GoodMapState();
}

class _GoodMapState extends State<GoodMap> {
  MapLibreMapController? _native;
  GoodMapController? _controller;
  int _cameraVersion = 0;
  bool _readyCalled = false;

  final Set<MarkerId> _declarativeMarkerIds = {};
  final Set<PopupId> _declarativePopupIds = {};

  void _syncMarkers() {
    final c = _controller;
    if (c == null) return;
    for (final id in _declarativeMarkerIds) {
      c.removeMarker(id);
    }
    _declarativeMarkerIds.clear();
    for (final marker in widget.markers) {
      final id = c.addMarker(marker);
      _declarativeMarkerIds.add(id);
    }
  }

  void _syncPopups() {
    final c = _controller;
    if (c == null) return;
    for (final id in _declarativePopupIds) {
      c.hidePopup(id);
    }
    _declarativePopupIds.clear();
    for (final popup in widget.popups) {
      final id = c.showPopup(popup.position, popup.child, alignment: popup.alignment);
      _declarativePopupIds.add(id);
    }
  }

  void _onMapCreated(MapLibreMapController native) {
    if (_controller != null) return; // idempotent: ignore re-fires
    setState(() {
      _native = native;
      _controller = GoodMapController(native)..addListener(_onOverlayChanged);
    });
  }

  void _onOverlayChanged() => setState(() {});

  void _onStyleLoaded() {
    if (!_readyCalled) {
      _readyCalled = true;
      _syncMarkers();
      _syncPopups();
      widget.onMapReady?.call(_controller!);
    } else {
      // Theme changed mid-session: GL-scene objects (symbols + lines) must be
      // re-applied to the new style.
      _controller!.reapplyGlObjects();
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _cameraVersion++);
    widget.onCameraChanged?.call(position);
  }

  @override
  void didUpdateWidget(GoodMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _readyCalled) {
      if (oldWidget.markers != widget.markers) {
        _syncMarkers();
      }
      if (oldWidget.popups != widget.popups) {
        _syncPopups();
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onOverlayChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.theme ?? GoodMapTheme.fromColorScheme(scheme);
    final style = basemapStyleFor(Theme.of(context).brightness);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.mapBuilder(
          styleString: style,
          initialCameraPosition: CameraPosition(
            target: widget.initialCenter,
            zoom: widget.initialZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoaded: _onStyleLoaded,
          onCameraMove: _onCameraMove,
        ),
        if (_native != null && _controller != null)
          GoodOverlayLayer(
            native: _native!,
            entries: _controller!.overlayEntries,
            cameraVersion: _cameraVersion,
          ),
        if (_native != null)
          GoodControlsView(
            native: _native!,
            config: widget.controls,
            theme: theme,
          ),
      ],
    );
  }
}

Widget _defaultMapBuilder({
  required String styleString,
  required CameraPosition initialCameraPosition,
  required void Function(MapLibreMapController) onMapCreated,
  required void Function() onStyleLoaded,
  required void Function(CameraPosition) onCameraMove,
}) {
  return MapLibreMap(
    styleString: styleString,
    initialCameraPosition: initialCameraPosition,
    trackCameraPosition: true,
    compassEnabled: false, // we render our own compass control
    onMapCreated: onMapCreated,
    onStyleLoadedCallback: onStyleLoaded,
    onCameraMove: onCameraMove,
  );
}
