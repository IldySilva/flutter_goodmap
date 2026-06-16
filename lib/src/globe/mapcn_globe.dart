import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'globe_camera.dart';

/// Phase-0 minimal globe: a drag-to-rotate orbit camera. The GPU draw is wired
/// in when [renderEnabled] is true (device only); widget tests run it false.
class MapcnGlobe extends StatefulWidget {
  const MapcnGlobe({
    required this.initialCenter,
    this.initialZoom = 2,
    this.onCameraChanged,
    this.renderEnabled = true,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final void Function(GlobeCamera camera)? onCameraChanged;
  final bool renderEnabled;

  @override
  State<MapcnGlobe> createState() => _MapcnGlobeState();
}

class _MapcnGlobeState extends State<MapcnGlobe> {
  late GlobeCamera _camera;

  @override
  void initState() {
    super.initState();
    _camera = GlobeCamera(
      center: widget.initialCenter,
      zoom: widget.initialZoom,
    );
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // ~0.3 degrees per logical pixel; horizontal -> lng, vertical -> lat.
    final rawLng = _camera.center.longitude - d.delta.dx * 0.3;
    final wrappedLng = ((rawLng + 180) % 360 + 360) % 360 - 180;
    final newLat = (_camera.center.latitude + d.delta.dy * 0.3).clamp(-89.0, 89.0);
    setState(() {
      _camera = _camera.copyWith(center: LatLng(newLat, wrappedLng));
    });
    widget.onCameraChanged?.call(_camera);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        // Phase 1+ replaces this child with the GPU Texture when
        // widget.renderEnabled is true.
        child: const SizedBox.expand(),
      ),
    );
  }
}
