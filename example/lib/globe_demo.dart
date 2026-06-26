import 'dart:async';

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

final _heatmapPoints = <LatLng>[
  LatLng(51.5, -0.1), // London
  LatLng(48.9, 2.35), // Paris
  LatLng(52.5, 13.4), // Berlin
  LatLng(40.7, -74.0), // New York
  LatLng(34.0, -118.2), // LA
  LatLng(37.8, -122.4), // SF
  LatLng(35.7, 139.7), // Tokyo
  LatLng(31.2, 121.5), // Shanghai
  LatLng(-33.9, 151.2), // Sydney
  LatLng(-23.5, -46.6), // São Paulo
  LatLng(19.1, 72.9), // Mumbai
  LatLng(1.35, 103.8), // Singapore
];

final _heatmapWeights = <double>[
  0.9,
  0.7,
  0.5,
  1.0,
  0.8,
  0.6,
  0.95,
  0.85,
  0.4,
  0.75,
  0.7,
  0.65,
];

/// The globe surface of the example app (Angola → world arcs).
class GlobeDemo extends StatefulWidget {
  const GlobeDemo({super.key});

  @override
  State<GlobeDemo> createState() => _GlobeDemoState();
}

class _GlobeDemoState extends State<GlobeDemo> {
  LatLng? _tapped;
  bool _showDottedGrid = false;
  bool _showHeatmap = false;
  bool _dayNight = false;
  DateTime _currentTime = DateTime.now().toUtc();
  Timer? _clockTimer;

  // Time-series: arc timestamps 0..7, slider controls filter end
  double _timeSlider = 7.0;
  bool _showTimeSlider = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _toggleDayNight() {
    setState(() => _dayNight = !_dayNight);
    if (_dayNight) {
      _currentTime = DateTime.now().toUtc();
      _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _currentTime = DateTime.now().toUtc());
      });
    } else {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  List<GlobeArc> get _filteredArcs {
    final List<GlobeArc> arcs = [];
    for (var i = 0; i < _cities.length; i++) {
      arcs.add(
        GlobeArc(
          from: _luanda,
          to: _cities[i].$2,
          drawProgress: 1.0,
          timestamp: i.toDouble(),
          dashed: true,
        ),
      );
    }
    return arcs;
  }

  List<MarkerOptions> get _markers => [
    const MarkerOptions(
      position: _luanda,
      label: 'Luanda',
      color: Colors.white,
      radius: 6,
      pulse: true,
      pulseMaxRadius: 22,
    ),
    for (final c in _cities)
      MarkerOptions(
        position: c.$2,
        label: c.$1,
        color: const Color(0xFF4F86F7),
        timestamp: _cities.indexOf(c).toDouble(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (double, double)? range = _showTimeSlider ? (0.0, _timeSlider) : null;

    return Stack(
      children: [
        Positioned.fill(
          child: GoodMapGlobe(
            initialCenter: _luanda,
            initialZoom: 1.0,
            markers: _markers,
            arcs: _filteredArcs,
            showDottedGrid: _showDottedGrid,
            dottedGridColor: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.22),
            heatmaps: _showHeatmap
                ? [
                    HeatmapOptions(
                      points: _heatmapPoints,
                      weights: _heatmapWeights,
                      radius: 28,
                      intensity: 1.2,
                    ),
                  ]
                : [],
            dateTime: _dayNight ? _currentTime : null,
            timeRange: range,
            atmosphere: _dayNight,
            onTap: (c) => setState(() => _tapped = c),
          ),
        ),

        // ── Feature toggles panel ────────────────────────────────────────
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                _ToggleChip(
                  icon: Icons.grain,
                  label: 'Dotted map',
                  active: _showDottedGrid,
                  onTap: () =>
                      setState(() => _showDottedGrid = !_showDottedGrid),
                ),
                _ToggleChip(
                  icon: Icons.thermostat,
                  label: 'Heatmap',
                  active: _showHeatmap,
                  onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                ),
                _ToggleChip(
                  icon: Icons.nightlight_round,
                  label: 'Day / Night',
                  active: _dayNight,
                  onTap: _toggleDayNight,
                ),
                _ToggleChip(
                  icon: Icons.timeline,
                  label: 'Time filter',
                  active: _showTimeSlider,
                  onTap: () =>
                      setState(() => _showTimeSlider = !_showTimeSlider),
                ),
              ],
            ),
          ),
        ),

        // ── Time-series slider ───────────────────────────────────────────
        if (_showTimeSlider)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: SafeArea(
              child: _TimeSlider(
                max: (_cities.length - 1).toDouble(),
                value: _timeSlider,
                onChanged: (v) => setState(() => _timeSlider = v),
              ),
            ),
          ),

        // ── Tapped coordinate badge ──────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? cs.onPrimary : cs.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlider extends StatelessWidget {
  const _TimeSlider({
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Show arcs up to: step ${value.round()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          Slider(
            value: value,
            min: 0,
            max: max,
            divisions: max.round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
