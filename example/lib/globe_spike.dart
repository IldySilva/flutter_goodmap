// MapcnGlobe demo.
// Run with:  flutter run -t lib/globe_spike.dart
//
// A minimalist, theme-aware 3D globe (CARTO dark/light basemap) with inertial
// drag-rotate, pinch-zoom, city points + labels, and dashed great-circle arcs.

import 'package:flutter/material.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() => runApp(const GlobeSpikeApp());

// London is the hub; arcs fan out to the other cities.
const _london = LatLng(51.50, -0.13);
const _cities = <(String, LatLng)>[
  ('New York', LatLng(40.71, -74.01)),
  ('San Francisco', LatLng(37.77, -122.42)),
  ('Dubai', LatLng(25.20, 55.27)),
  ('Mumbai', LatLng(19.08, 72.88)),
  ('Singapore', LatLng(1.35, 103.82)),
  ('São Paulo', LatLng(-23.55, -46.63)),
  ('Luanda', LatLng(-8.84, 13.23)),
  ('Sydney', LatLng(-33.87, 151.21)),
];

final _points = <GlobePoint>[
  const GlobePoint(
      coordinate: _london, label: 'London', color: Colors.white, radius: 6),
  for (final c in _cities)
    GlobePoint(coordinate: c.$2, label: c.$1, color: const Color(0xFF4F86F7)),
];

final _arcs = <GlobeArc>[
  for (final c in _cities) GlobeArc(from: _london, to: c.$2),
];

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
                initialCenter: const LatLng(25, 15),
                initialZoom: 1.0,
                points: _points,
                arcs: _arcs,
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
