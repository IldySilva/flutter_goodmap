// MapcnGlobe demo.
// Run with:  flutter run -t lib/globe_spike.dart
//
// A minimalist, theme-aware 3D globe (CARTO dark/light basemap) with inertial
// drag-rotate and pinch-zoom. Toggle the brightness with the app-bar button.

import 'package:flutter/material.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() => runApp(const GlobeSpikeApp());

class GlobeSpikeApp extends StatefulWidget {
  const GlobeSpikeApp({super.key});

  @override
  State<GlobeSpikeApp> createState() => _GlobeSpikeAppState();
}

class _GlobeSpikeAppState extends State<GlobeSpikeApp> {
  ThemeMode _mode = ThemeMode.dark;
  LatLng? _tapped;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('mapcn globe'),
          actions: [
            IconButton(
              tooltip: 'Toggle light/dark',
              icon: Icon(
                  _mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _mode =
                  _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: MapcnGlobe(
                initialCenter: const LatLng(20, 0),
                initialZoom: 1.0,
                onTap: (c) => setState(() => _tapped = c),
              ),
            ),
            if (_tapped != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_tapped!.latitude.toStringAsFixed(2)}, '
                    '${_tapped!.longitude.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
