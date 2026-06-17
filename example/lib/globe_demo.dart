import 'package:flutter/material.dart';
import 'package:goodmap/goodmap.dart';

// Luanda is the hub; arcs fan out from Angola to the world.
const _luanda = LatLng(-8.84, 13.23);
const _cities = <(String, LatLng)>[
  ('London', LatLng(51.50, -0.13)),
  ('New York', LatLng(40.71, -74.01)),
  ('San Francisco', LatLng(37.77, -122.42)),
  ('Dubai', LatLng(25.20, 55.27)),
  ('Mumbai', LatLng(19.08, 72.88)),
  ('Singapore', LatLng(1.35, 103.82)),
  ('São Paulo', LatLng(-23.55, -46.63)),
  ('Sydney', LatLng(-33.87, 151.21)),
];

final _points = <GlobePoint>[
  const GlobePoint(
    coordinate: _luanda,
    label: 'Luanda',
    color: Colors.white,
    radius: 6,
  ),
  for (final c in _cities)
    GlobePoint(coordinate: c.$2, label: c.$1, color: const Color(0xFF4F86F7)),
];

final _arcs = <GlobeArc>[
  for (final c in _cities) GlobeArc(from: _luanda, to: c.$2),
];

/// The globe surface of the example app (Angola → world arcs).
class GlobeDemo extends StatefulWidget {
  const GlobeDemo({super.key});

  @override
  State<GlobeDemo> createState() => _GlobeDemoState();
}

class _GlobeDemoState extends State<GlobeDemo> {
  LatLng? _tapped;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GoodMapGlobe(
            initialCenter: _luanda,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}
