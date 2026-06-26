import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:goodmap/src/globe/good_globe.dart';
import 'package:goodmap/src/markers/marker.dart';
import 'package:goodmap/src/popups/popup.dart';

void main() {
  testWidgets('horizontal drag changes the camera longitude', (tester) async {
    LatLng? seen;
    await tester.pumpWidget(MaterialApp(
      home: GoodGlobe(
        initialCenter: const LatLng(0, 0),
        onCameraChanged: (c, z) => seen = c,
        renderEnabled: false,
      ),
    ));
    await tester.drag(find.byType(GoodGlobe), const Offset(100, 0));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.longitude, isNot(0));
  });

  testWidgets('vertical drag changes latitude and clamps near the poles',
      (tester) async {
    LatLng? seen;
    await tester.pumpWidget(MaterialApp(
      home: GoodGlobe(
        initialCenter: const LatLng(0, 0),
        onCameraChanged: (c, z) => seen = c,
        renderEnabled: false,
      ),
    ));
    await tester.drag(find.byType(GoodGlobe), const Offset(0, 5000));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.latitude, lessThanOrEqualTo(85.0));
    expect(seen!.latitude, greaterThan(0));
  });

  testWidgets('renders and projects interactive markers and popups on the globe',
      (tester) async {
    var tapped = false;
    final markers = [
      MarkerOptions(
        position: const LatLng(0, 0), // center of front face, visible
        child: const Text('Globe Marker', key: Key('globe_marker')),
        onTap: () => tapped = true,
      ),
      const MarkerOptions(
        position: LatLng(0, 180), // antipode, hidden/occluded behind the globe
        child: Text('Hidden Marker', key: Key('hidden_marker')),
      ),
    ];

    final popups = [
      const PopupOptions(
        position: LatLng(0, 0), // visible
        child: Text('Globe Popup', key: Key('globe_popup')),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoodGlobe(
          initialCenter: const LatLng(0, 0),
          markers: markers,
          popups: popups,
          renderEnabled: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify visible marker and popup are rendered
    expect(find.byKey(const Key('globe_marker')), findsOneWidget);
    expect(find.byKey(const Key('globe_popup')), findsOneWidget);

    // Verify hidden/occluded marker is NOT rendered
    expect(find.byKey(const Key('hidden_marker')), findsNothing);

    // Tap visible marker
    await tester.tap(find.byKey(const Key('globe_marker')), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isTrue);
  });
}
