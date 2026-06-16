// Phase 1 integration test for MapcnGlobe.
// Run with:  flutter run -t lib/globe_spike.dart
//
// Renders the integrated MapcnGlobe widget containing the live TileAtlas
// (fetching, caching, and GPU-reprojecting real CARTO map tiles). Drag to rotate.

import 'package:flutter/material.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() => runApp(const GlobeSpikeApp());

class GlobeSpikeApp extends StatelessWidget {
  const GlobeSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Color(0xFF101418),
        body: SafeArea(
          child: MapcnGlobe(
            initialCenter: LatLng(20.0, 0.0),
            initialZoom: 1.5,
          ),
        ),
      ),
    );
  }
}
