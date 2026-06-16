// lib/src/mapcn_controller.dart
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'internal/registry.dart';
import 'markers/marker.dart';
import 'popups/popup.dart';

/// Single point of imperative interaction with a [MapcnMap]. Wraps the native
/// [MapLibreMapController] and owns the marker + popup registries. Notifies
/// listeners (the overlay layer) whenever overlay entries change.
class MapcnController extends ChangeNotifier {
  MapcnController(this._native) {
    _markers.addListener(notifyListeners);
    _popups.addListener(notifyListeners);
  }

  final MapLibreMapController _native;
  final Registry<MarkerOptions> _markers = Registry<MarkerOptions>();
  final Registry<PopupOptions> _popups = Registry<PopupOptions>();

  // --- Camera -------------------------------------------------------------

  Future<void> flyTo(LatLng target, {double? zoom}) async {
    final update = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newLatLngZoom(target, zoom);
    await _native.animateCamera(update);
  }

  Future<void> animateTo(CameraPosition position) async {
    await _native.animateCamera(CameraUpdate.newCameraPosition(position));
  }

  Future<void> fitBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(40),
  }) async {
    await _native.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
    );
  }

  Future<void> moveTo(LatLng target, {double? zoom}) async {
    final update = zoom == null
        ? CameraUpdate.newLatLng(target)
        : CameraUpdate.newLatLngZoom(target, zoom);
    await _native.moveCamera(update);
  }

  // Maps marker id -> native Symbol for image markers (GL-scene path).
  final Map<int, Symbol> _symbols = <int, Symbol>{};

  // --- Markers ------------------------------------------------------------

  MarkerId addMarker(MarkerOptions options) {
    final int id = _markers.add(options);
    if (options.image != null) {
      _createSymbol(id, options);
    }
    return MarkerId(id);
  }

  void updateMarker(MarkerId id, MarkerOptions options) {
    if (!_markers.items.containsKey(id.value)) return;
    _markers.update(id.value, options);
    if (options.image != null) {
      _createSymbol(id.value, options); // re-create to reflect new position/icon
    }
  }

  void removeMarker(MarkerId id) {
    if (!_markers.items.containsKey(id.value)) return;
    _markers.remove(id.value);
    _disposeSymbol(id.value);
  }

  void clearMarkers() {
    for (final symbol in _symbols.values) {
      _native.removeSymbol(symbol);
    }
    _symbols.clear();
    _markers.clear();
  }

  Future<void> _createSymbol(int id, MarkerOptions options) async {
    final image = options.image!;
    final Uint8List bytes =
        (await rootBundle.load(image.assetName)).buffer.asUint8List();
    await _native.addImage(image.assetName, bytes);
    final Symbol symbol = await _native.addSymbol(
      SymbolOptions(
        geometry: options.position,
        iconImage: image.assetName,
        iconSize: 1,
      ),
    );
    _symbols[id] = symbol;
  }

  void _disposeSymbol(int id) {
    final symbol = _symbols.remove(id);
    if (symbol != null) _native.removeSymbol(symbol);
  }

  /// All overlay-widget entries (child-markers + popups) to be projected.
  /// Popups are appended in Task 8.
  List<OverlayEntryData> get overlayEntries => <OverlayEntryData>[
        for (final entry in _markers.items.entries)
          if (entry.value.child != null)
            OverlayEntryData(
              key: MarkerId(entry.key),
              position: entry.value.position,
              alignment: entry.value.alignment,
              onTap: entry.value.onTap,
              child: entry.value.child!,
            ),
      ];

  @override
  void dispose() {
    _markers.dispose();
    _popups.dispose();
    super.dispose();
  }
}

/// A geographically-anchored widget the overlay layer projects onto the screen.
@immutable
class OverlayEntryData {
  const OverlayEntryData({
    required this.key,
    required this.position,
    required this.child,
    required this.alignment,
    this.onTap,
  });
  final Object key;
  final LatLng position;
  final Widget child;
  final Alignment alignment;
  final VoidCallback? onTap;
}
