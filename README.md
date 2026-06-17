# goodmap

Theme-aware, ready-to-use Flutter map components built on
[`maplibre_gl`](https://pub.dev/packages/maplibre_gl). iOS and Android.

## Install

```yaml
dependencies:
  goodmap: ^0.1.0
```

## Platform setup

`maplibre_gl` requires iOS 13+ and Android `minSdkVersion 21`.

## Usage

```dart
import 'package:goodmap/goodmap.dart';

GoodMap(
  initialCenter: const LatLng(37.77, -122.42),
  initialZoom: 11,
  controls: const GoodControls(zoom: true, compass: true),
  onMapReady: (c) {
    final id = c.addMarker(MarkerOptions(
      position: const LatLng(37.77, -122.42),
      child: const Icon(Icons.location_on),
      onTap: () => c.showPopup(
        const LatLng(37.77, -122.42),
        const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('SF'))),
      ),
    ));
  },
)
```

The basemap follows `Theme.of(context).brightness` (CARTO positron / dark-matter).

## Controller API

- **Camera:** `flyTo`, `animateTo`, `fitBounds`, `moveTo`
- **Markers:** `addMarker`, `updateMarker`, `removeMarker`, `clearMarkers`
- **Popups:** `showPopup`, `hidePopup`, `clearPopups`

## Basemap terms

The example app uses CARTO's public basemap styles. Review CARTO's terms before
production use and supply your own style URL via a custom `GoodMapTheme`/basemap
if required.

## License

MIT
