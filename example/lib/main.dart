import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goodmap/goodmap.dart';

import 'demo_data.dart';
import 'demo_widgets.dart';
import 'globe_demo.dart';

void main() => runApp(const ExampleApp());

const LatLng _sfCenter = LatLng(37.7749, -122.4194);

/// Fixed drop spots for the native GL-symbol (asset) markers.
const List<LatLng> _glPinSpots = [
  LatLng(37.7890, -122.4010),
  LatLng(37.7760, -122.4160),
  LatLng(37.8080, -122.4200),
];

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;
  bool _customTheme = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'goodmap example',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: DemoHome(
        customTheme: _customTheme,
        isDark: _mode == ThemeMode.dark,
        onToggleBrightness: () => setState(
          () => _mode = _mode == ThemeMode.light
              ? ThemeMode.dark
              : ThemeMode.light,
        ),
        onToggleCustomTheme: () => setState(() => _customTheme = !_customTheme),
      ),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({
    required this.customTheme,
    required this.isDark,
    required this.onToggleBrightness,
    required this.onToggleCustomTheme,
    super.key,
  });

  final bool customTheme;
  final bool isDark;
  final VoidCallback onToggleBrightness;
  final VoidCallback onToggleCustomTheme;

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  GoodMapController? _controller;
  PopupId? _activePopup;
  bool _showGlobe = false;

  // Live marker (updateMarker on a timer).
  MarkerId? _liveMarker;
  Timer? _liveTimer;
  double _routeT = 0;

  // Native GL-symbol (asset) markers.
  final List<MarkerId> _glPins = [];

  // Polylines / routes.
  PolylineId? _poiRoute;
  PolylineId? _ferryLine;

  // v0.4.0 flat map features.
  HeatmapId? _heatmap;
  bool _buildings3D = false;

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _onMapReady(GoodMapController c) {
    _controller = c;
    for (final poi in kPois) {
      c.addMarker(
        MarkerOptions(
          position: poi.position,
          alignment: Alignment.bottomCenter,
          child: PoiPin(poi: poi),
          onTap: () => _showPoiPopup(poi),
        ),
      );
    }
    c.fitBounds(poiBounds(), padding: const EdgeInsets.all(72));
    setState(() {}); // enable the control panel
  }

  void _showPoiPopup(Poi poi) {
    final c = _controller!;
    if (_activePopup != null) c.hidePopup(_activePopup!);
    late PopupId id;
    id = c.showPopup(
      poi.position,
      PoiPopupCard(
        poi: poi,
        onClose: () {
          c.hidePopup(id);
          _activePopup = null;
        },
      ),
    );
    _activePopup = id;
  }

  // --- Heatmap (v0.4.0) ---------------------------------------------------

  void _toggleHeatmap() async {
    final c = _controller;
    if (c == null) return;
    if (_heatmap != null) {
      await c.removeHeatmap(_heatmap!);
      setState(() => _heatmap = null);
      return;
    }
    // A handful of SF landmarks as heatmap points.
    const points = [
      LatLng(37.8199, -122.4783), // Golden Gate Bridge
      LatLng(37.7749, -122.4194), // City Hall
      LatLng(37.7954, -122.3936), // Ferry Building
      LatLng(37.8030, -122.4487), // Presidio
      LatLng(37.7697, -122.4669), // Twin Peaks
      LatLng(37.7608, -122.5093), // Ocean Beach
      LatLng(37.7873, -122.4040), // Union Square
      LatLng(37.7591, -122.4295), // Mission
    ];
    const weights = [0.95, 0.7, 0.8, 0.6, 0.75, 0.5, 0.85, 0.65];
    final id = await c.addHeatmap(
      const HeatmapOptions(points: points, weights: weights, radius: 30),
    );
    setState(() => _heatmap = id);
  }

  // --- 3D Buildings (v0.4.0) ----------------------------------------------

  void _toggleBuildings3D() async {
    final c = _controller;
    if (c == null) return;
    if (_buildings3D) {
      await c.disableBuildings3D();
      setState(() => _buildings3D = false);
    } else {
      // Zoom into the Financial District for best effect.
      await c.animateTo(
        const CameraPosition(
          target: LatLng(37.7946, -122.3999),
          zoom: 15.5,
          tilt: 55,
          bearing: 20,
        ),
      );
      await c.enableBuildings3D();
      setState(() => _buildings3D = true);
    }
  }

  // --- Camera demos -------------------------------------------------------

  void _flyToBridge() =>
      _controller?.flyTo(const LatLng(37.8199, -122.4783), zoom: 14);

  void _fitAll() =>
      _controller?.fitBounds(poiBounds(), padding: const EdgeInsets.all(72));

  void _tiltAndRotate() => _controller?.animateTo(
    const CameraPosition(target: _sfCenter, zoom: 12.5, bearing: 45, tilt: 45),
  );

  // "Mapa mundi": zoom out to the whole flat world map.
  void _worldView() => _controller?.animateTo(
    const CameraPosition(target: LatLng(20, 0), zoom: 1),
  );

  // --- Routes / polylines -------------------------------------------------

  void _togglePoiRoute() {
    final c = _controller;
    if (c == null) return;
    if (_poiRoute != null) {
      c.removePolyline(_poiRoute!);
      setState(() => _poiRoute = null);
      return;
    }
    final id = c.addPolyline(
      [for (final p in kPois) p.position],
      color: Theme.of(context).colorScheme.primary,
      width: 5,
    );
    setState(() => _poiRoute = id);
  }

  // --- Live marker --------------------------------------------------------

  void _toggleLiveMarker() {
    final c = _controller;
    if (c == null) return;
    if (_liveMarker != null) {
      _liveTimer?.cancel();
      _liveTimer = null;
      c.removeMarker(_liveMarker!);
      if (_ferryLine != null) c.removePolyline(_ferryLine!);
      _ferryLine = null;
      setState(() => _liveMarker = null);
      return;
    }
    // Draw the route the ferry follows, then animate a marker along it.
    _ferryLine = c.addPolyline(
      const [...kFerryRoute, LatLng(37.7955, -122.3937)],
      color: Colors.teal,
      width: 4,
    );
    _routeT = 0;
    final id = c.addMarker(
      const MarkerOptions(
        position: LatLng(37.7955, -122.3937),
        alignment: Alignment.bottomCenter,
        child: LiveBadge(label: 'Ferry · live'),
      ),
    );
    _liveTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _routeT = (_routeT + 0.18) % kFerryRoute.length;
      final seg = _routeT.floor();
      final frac = _routeT - seg;
      final a = kFerryRoute[seg];
      final b = kFerryRoute[(seg + 1) % kFerryRoute.length];
      final pos = LatLng(
        a.latitude + (b.latitude - a.latitude) * frac,
        a.longitude + (b.longitude - a.longitude) * frac,
      );
      c.updateMarker(
        id,
        MarkerOptions(
          position: pos,
          alignment: Alignment.bottomCenter,
          child: const LiveBadge(label: 'Ferry · live'),
        ),
      );
    });
    setState(() => _liveMarker = id);
  }

  // --- Native GL-symbol markers -------------------------------------------

  void _toggleGlPins() {
    final c = _controller;
    if (c == null) return;
    if (_glPins.isNotEmpty) {
      for (final id in _glPins) {
        c.removeMarker(id);
      }
      setState(() => _glPins.clear());
      return;
    }
    final ids = <MarkerId>[];
    for (final spot in _glPinSpots) {
      ids.add(
        c.addMarker(
          MarkerOptions(
            position: spot,
            image: MarkerImage.asset(
              'assets/pin_teal.png',
              size: const Size(40, 40),
            ),
          ),
        ),
      );
    }
    setState(() => _glPins.addAll(ids));
  }

  GoodMapTheme? _mapTheme(BuildContext context) {
    if (!widget.customTheme) return null;
    final scheme = Theme.of(context).colorScheme;
    return GoodMapTheme.fromColorScheme(scheme).copyWith(
      controlBackground: Colors.deepOrange,
      controlForeground: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller != null;
    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Flat'),
              icon: Icon(Icons.map_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Globe'),
              icon: Icon(Icons.public),
            ),
          ],
          selected: {_showGlobe},
          onSelectionChanged: (s) => setState(() => _showGlobe = s.first),
        ),
        actions: [
          if (!_showGlobe)
            IconButton(
              tooltip: widget.customTheme
                  ? 'Default control theme'
                  : 'Custom control theme',
              icon: Icon(
                widget.customTheme ? Icons.palette : Icons.palette_outlined,
              ),
              onPressed: widget.onToggleCustomTheme,
            ),
          IconButton(
            tooltip: 'Toggle light/dark',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleBrightness,
          ),
        ],
      ),
      body: _showGlobe
          ? const GlobeDemo()
          : Column(
              children: [
                Expanded(
                  child: GoodMap(
                    initialCenter: _sfCenter,
                    initialZoom: 11,
                    controls: const GoodControls(zoom: true, compass: true),
                    theme: _mapTheme(context),
                    onMapReady: _onMapReady,
                  ),
                ),
                _ControlPanel(
                  enabled: ready,
                  liveOn: _liveMarker != null,
                  glOn: _glPins.isNotEmpty,
                  routeOn: _poiRoute != null,
                  heatmapOn: _heatmap != null,
                  buildings3DOn: _buildings3D,
                  onFitAll: _fitAll,
                  onFlyToBridge: _flyToBridge,
                  onTilt: _tiltAndRotate,
                  onWorld: _worldView,
                  onToggleRoute: _togglePoiRoute,
                  onToggleLive: _toggleLiveMarker,
                  onToggleGl: _toggleGlPins,
                  onToggleHeatmap: _toggleHeatmap,
                  onToggleBuildings3D: _toggleBuildings3D,
                  onClearPopups: () {
                    _controller?.clearPopups();
                    _activePopup = null;
                  },
                ),
              ],
            ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.enabled,
    required this.liveOn,
    required this.glOn,
    required this.routeOn,
    required this.heatmapOn,
    required this.buildings3DOn,
    required this.onFitAll,
    required this.onFlyToBridge,
    required this.onTilt,
    required this.onWorld,
    required this.onToggleRoute,
    required this.onToggleLive,
    required this.onToggleGl,
    required this.onToggleHeatmap,
    required this.onToggleBuildings3D,
    required this.onClearPopups,
  });

  final bool enabled;
  final bool liveOn;
  final bool glOn;
  final bool routeOn;
  final bool heatmapOn;
  final bool buildings3DOn;
  final VoidCallback onFitAll;
  final VoidCallback onFlyToBridge;
  final VoidCallback onTilt;
  final VoidCallback onWorld;
  final VoidCallback onToggleRoute;
  final VoidCallback onToggleLive;
  final VoidCallback onToggleGl;
  final VoidCallback onToggleHeatmap;
  final VoidCallback onToggleBuildings3D;
  final VoidCallback onClearPopups;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap a pin for a popup. Try the demos:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DemoButton(
                      icon: Icons.fit_screen,
                      label: 'Fit all',
                      onTap: enabled ? onFitAll : null,
                    ),
                    _DemoButton(
                      icon: Icons.flight_takeoff,
                      label: 'Fly to bridge',
                      onTap: enabled ? onFlyToBridge : null,
                    ),
                    _DemoButton(
                      icon: Icons.threed_rotation,
                      label: 'Tilt & rotate',
                      onTap: enabled ? onTilt : null,
                    ),
                    _DemoButton(
                      icon: Icons.public,
                      label: 'World',
                      onTap: enabled ? onWorld : null,
                    ),
                    _DemoButton(
                      icon: routeOn ? Icons.timeline : Icons.route,
                      label: routeOn ? 'Hide route' : 'POI route',
                      selected: routeOn,
                      onTap: enabled ? onToggleRoute : null,
                    ),
                    _DemoButton(
                      icon: liveOn ? Icons.stop_circle : Icons.directions_boat,
                      label: liveOn ? 'Stop ferry' : 'Live ferry',
                      selected: liveOn,
                      onTap: enabled ? onToggleLive : null,
                    ),
                    _DemoButton(
                      icon: glOn ? Icons.layers_clear : Icons.place,
                      label: glOn ? 'Clear GL pins' : 'Drop GL pins',
                      selected: glOn,
                      onTap: enabled ? onToggleGl : null,
                    ),
                    _DemoButton(
                      icon: heatmapOn
                          ? Icons.thermostat_outlined
                          : Icons.thermostat,
                      label: heatmapOn ? 'Clear heatmap' : 'Heatmap',
                      selected: heatmapOn,
                      onTap: enabled ? onToggleHeatmap : null,
                    ),
                    _DemoButton(
                      icon: buildings3DOn
                          ? Icons.apartment
                          : Icons.domain_outlined,
                      label: buildings3DOn ? 'Hide 3D bldgs' : '3D buildings',
                      selected: buildings3DOn,
                      onTap: enabled ? onToggleBuildings3D : null,
                    ),
                    _DemoButton(
                      icon: Icons.close_fullscreen,
                      label: 'Clear popups',
                      onTap: enabled ? onClearPopups : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = selected
        ? FilledButton.styleFrom()
        : FilledButton.styleFrom(
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
          );
    return FilledButton.icon(
      style: style,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
