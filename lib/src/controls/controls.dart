// lib/src/controls/controls.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../theme/good_map_theme.dart';

/// Declares which on-map controls are shown. Fullscreen and locate are out of
/// scope for v1 (see design spec).
@immutable
class GoodControls {
  const GoodControls({this.zoom = true, this.compass = true});
  final bool zoom;
  final bool compass;
}

/// Renders the configured controls and wires them to the native controller.
class GoodControlsView extends StatelessWidget {
  const GoodControlsView({
    required this.native,
    required this.config,
    required this.theme,
    super.key,
  });

  final MapLibreMapController native;
  final GoodControls config;
  final GoodMapTheme theme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          if (config.zoom) ...[
            _button(
              key: const ValueKey('mapcn_zoom_in'),
              icon: Icons.add,
              onTap: () => native.animateCamera(CameraUpdate.zoomIn()),
            ),
            const SizedBox(height: 8),
            _button(
              key: const ValueKey('mapcn_zoom_out'),
              icon: Icons.remove,
              onTap: () => native.animateCamera(CameraUpdate.zoomOut()),
            ),
          ],
          if (config.zoom && config.compass) const SizedBox(height: 8),
          if (config.compass)
            _button(
              key: const ValueKey('mapcn_compass'),
              icon: Icons.explore_outlined,
              onTap: () => native.animateCamera(CameraUpdate.bearingTo(0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: theme.controlBackground,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: theme.controlForeground),
        ),
      ),
    );
  }
}
