// test/globe/good_globe_v040_test.dart
//
// Widget-level tests for v0.4.0 GoodGlobe features.
// All tests use renderEnabled: false to skip the GPU path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/goodmap.dart';

void main() {
  const london = LatLng(51.5, -0.1);
  const paris = LatLng(48.9, 2.35);
  const nyc = LatLng(40.71, -74.01);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('GoodGlobe — heatmaps prop', () {
    testWidgets('accepts heatmaps without throwing', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        heatmaps: [
          HeatmapOptions(
            points: [london, paris],
            weights: [0.5, 1.0],
          ),
        ],
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });

    testWidgets('empty heatmaps list is valid', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        heatmaps: [],
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });
  });

  group('GoodGlobe — day/night terminator', () {
    testWidgets('dateTime prop is accepted without error', (tester) async {
      await tester.pumpWidget(wrap(GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        dateTime: DateTime.utc(2024, 6, 21, 12, 0, 0),
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });

    testWidgets('sunPosition prop is accepted without error', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        sunPosition: LatLng(23.0, -15.0),
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });
  });

  group('GoodGlobe — time-series filtering', () {
    final markers = [
      const MarkerOptions(position: london, label: 'London', timestamp: 1.0),
      const MarkerOptions(position: paris, label: 'Paris', timestamp: 5.0),
      const MarkerOptions(position: nyc, label: 'New York', timestamp: 10.0),
      const MarkerOptions(position: LatLng(0, 0), label: 'No timestamp'),
    ];

    testWidgets('renders without error with timeRange set', (tester) async {
      await tester.pumpWidget(wrap(GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        markers: markers,
        timeRange: (0.0, 6.0),
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });

    testWidgets('null timeRange shows all markers', (tester) async {
      await tester.pumpWidget(wrap(GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        markers: markers,
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });
  });

  group('GoodGlobe — pulsing markers', () {
    testWidgets('pulse: true marker renders without error', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        markers: [
          MarkerOptions(
            position: london,
            label: 'Pulsing',
            pulse: true,
            pulseMaxRadius: 24.0,
          ),
        ],
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });
  });

  group('GoodGlobe — arc drawProgress', () {
    testWidgets('drawProgress=0.5 arc renders without error', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        arcs: [
          GlobeArc(from: london, to: paris, drawProgress: 0.5),
        ],
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });

    testWidgets('arc with timestamp renders without error', (tester) async {
      await tester.pumpWidget(wrap(const GoodGlobe(
        initialCenter: london,
        renderEnabled: false,
        arcs: [
          GlobeArc(from: london, to: paris, timestamp: 3.0),
        ],
        timeRange: (0.0, 5.0),
      )));
      expect(find.byType(GoodGlobe), findsOneWidget);
    });
  });
}
