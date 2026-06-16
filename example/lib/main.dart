import 'package:flutter/material.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mapcn_flutter example',
      themeMode: _mode,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('mapcn_flutter'),
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6),
              onPressed: () => setState(() => _mode =
                  _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
            ),
          ],
        ),
        body: MapcnMap(
          initialCenter: const LatLng(37.77, -122.42),
          initialZoom: 11,
          controls: const MapcnControls(zoom: true, compass: true),
          onMapReady: (c) {
            c.addMarker(MarkerOptions(
              position: const LatLng(37.77, -122.42),
              alignment: Alignment.bottomCenter,
              child: const Icon(Icons.location_on, color: Colors.indigo, size: 36),
              onTap: () => c.showPopup(
                const LatLng(37.77, -122.42),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: const Text('San Francisco'),
                  ),
                ),
              ),
            ));
            c.flyTo(const LatLng(37.77, -122.42), zoom: 12);
          },
        ),
      ),
    );
  }
}
