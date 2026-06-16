// lib/src/mapcn_map.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'controls/controls.dart';
import 'mapcn_controller.dart';
import 'popups/popup_layer.dart';
import 'theme/basemaps.dart';
import 'theme/mapcn_theme.dart';

export 'controls/controls.dart' show MapcnControls;

/// Test seam: builds the native map view. Production uses [_defaultMapBuilder].
typedef MapcnMapBuilder = Widget Function({
  required String styleString,
  required CameraPosition initialCameraPosition,
  required void Function(MapLibreMapController) onMapCreated,
  required void Function() onStyleLoaded,
  required void Function(CameraPosition) onCameraMove,
});

/// A theme-aware map with overlay markers/popups and zoom/compass controls.
class MapcnMap extends StatefulWidget {
  const MapcnMap({
    required this.initialCenter,
    required this.onMapReady,
    this.initialZoom = 11,
    this.controls = const MapcnControls(),
    this.theme,
    @visibleForTesting this.mapBuilder = _defaultMapBuilder,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final MapcnControls controls;
  final MapcnTheme? theme;
  final void Function(MapcnController) onMapReady;
  final MapcnMapBuilder mapBuilder;

  @override
  State<MapcnMap> createState() => _MapcnMapState();
}

class _MapcnMapState extends State<MapcnMap> {
  MapLibreMapController? _native;
  MapcnController? _controller;
  int _cameraVersion = 0;
  bool _readyCalled = false;

  void _onMapCreated(MapLibreMapController native) {
    if (_controller != null) return; // idempotent: ignore re-fires
    setState(() {
      _native = native;
      _controller = MapcnController(native)..addListener(_onOverlayChanged);
    });
  }

  void _onOverlayChanged() => setState(() {});

  void _onStyleLoaded() {
    if (!_readyCalled) {
      _readyCalled = true;
      widget.onMapReady(_controller!);
    } else {
      // Theme changed mid-session: GL-scene objects (symbols + lines) must be
      // re-applied to the new style.
      _controller!.reapplyGlObjects();
    }
  }

  void _onCameraMove(CameraPosition _) =>
      setState(() => _cameraVersion++);

  @override
  void dispose() {
    _controller?.removeListener(_onOverlayChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.theme ?? MapcnTheme.fromColorScheme(scheme);
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
          MapcnOverlayLayer(
            native: _native!,
            entries: _controller!.overlayEntries,
            cameraVersion: _cameraVersion,
          ),
        if (_native != null)
          MapcnControlsView(
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
