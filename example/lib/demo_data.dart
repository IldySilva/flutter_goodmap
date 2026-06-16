import 'package:flutter/material.dart';
import 'package:mapcn_flutter/mapcn.dart';

/// A point of interest shown as an overlay marker with a tappable popup.
class Poi {
  const Poi({
    required this.name,
    required this.subtitle,
    required this.position,
    required this.icon,
    required this.color,
  });

  final String name;
  final String subtitle;
  final LatLng position;
  final IconData icon;
  final Color color;
}

/// A handful of San Francisco landmarks used across the demo.
const List<Poi> kPois = [
  Poi(
    name: 'Ferry Building',
    subtitle: 'Marketplace & terminal',
    position: LatLng(37.7955, -122.3937),
    icon: Icons.directions_boat,
    color: Color(0xFF3F51B5),
  ),
  Poi(
    name: 'Coit Tower',
    subtitle: 'Telegraph Hill landmark',
    position: LatLng(37.8024, -122.4058),
    icon: Icons.tour,
    color: Color(0xFF009688),
  ),
  Poi(
    name: 'Oracle Park',
    subtitle: 'Bayfront ballpark',
    position: LatLng(37.7786, -122.3893),
    icon: Icons.sports_baseball,
    color: Color(0xFFE65100),
  ),
  Poi(
    name: 'Golden Gate Bridge',
    subtitle: 'The icon itself',
    position: LatLng(37.8199, -122.4783),
    icon: Icons.directions_car,
    color: Color(0xFFC62828),
  ),
  Poi(
    name: 'Twin Peaks',
    subtitle: 'Panoramic viewpoint',
    position: LatLng(37.7544, -122.4477),
    icon: Icons.landscape,
    color: Color(0xFF6A1B9A),
  ),
];

/// Bounds that frame every [kPois] entry — used by the "Fit all" camera demo.
LatLngBounds poiBounds() {
  var minLat = kPois.first.position.latitude;
  var maxLat = minLat;
  var minLng = kPois.first.position.longitude;
  var maxLng = minLng;
  for (final p in kPois) {
    minLat = p.position.latitude < minLat ? p.position.latitude : minLat;
    maxLat = p.position.latitude > maxLat ? p.position.latitude : maxLat;
    minLng = p.position.longitude < minLng ? p.position.longitude : minLng;
    maxLng = p.position.longitude > maxLng ? p.position.longitude : maxLng;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// A looping route for the live "ferry" marker (updateMarker on a timer).
const List<LatLng> kFerryRoute = [
  LatLng(37.7955, -122.3937), // Ferry Building
  LatLng(37.8080, -122.4090),
  LatLng(37.8240, -122.4220),
  LatLng(37.8199, -122.4783), // toward the bridge
  LatLng(37.8080, -122.4400),
];
