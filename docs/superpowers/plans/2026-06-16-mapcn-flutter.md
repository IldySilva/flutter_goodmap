# mapcn for Flutter — v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a pub.dev Flutter package that wraps `maplibre_gl` with a themed map widget, a controller-based imperative API for camera/markers/popups, and zoom + compass controls, targeting iOS and Android.

**Architecture:** `MapcnMap` is a `StatefulWidget` that renders a `Stack` of a native `MapLibreMap` (basemap style chosen from `Theme.brightness`), an overlay projection layer, and a controls layer. A `MapcnController` (a `ChangeNotifier`) wraps the native `MapLibreMapController` and owns two pure-Dart registries (markers, popups). Overlay widgets are positioned by projecting their `LatLng` to screen offsets via `controller.toScreenLocation`, re-projected on every camera move. Marker `image` symbols take the native GL-scene path via `addSymbol`.

**Tech Stack:** Dart/Flutter (SDK >= 3.7.0, Flutter >= 3.22.0), `maplibre_gl` ^0.26.1, `flutter_test`, `mocktail` for mocking the native controller. CARTO positron/dark-matter vector basemaps.

---

## Scope Notes

- **In v1:** themed `MapcnMap`, `MapcnController` (camera + markers + popups), overlay-widget markers (default), asset-image GL-symbol markers (`MarkerImage.asset`), overlay popups, `MapcnControls` (zoom + compass/reset-bearing), light/dark basemap selection + style reload.
- **Deferred (not in this plan):** `MarkerImage.widget` (widget-to-image snapshot → GL symbol). The spec marks `widget_to_image.dart` as *optional*; the default overlay-widget path already covers rich-widget markers, so the snapshot path is a post-v1 addition. `MarkerImage` ships with `.asset` only. Do **not** invent a `.widget` factory in this plan.
- **Out of scope per spec:** web/desktop, data layers, demo blocks, registry/CLI distribution, locate/fullscreen controls, forking `maplibre_gl`.

## File Structure

```
mapcn_flutter/
├── lib/
│   ├── mapcn.dart                       # public exports
│   └── src/
│       ├── mapcn_map.dart               # MapcnMap widget (Stack: map + overlay + controls)
│       ├── mapcn_controller.dart        # MapcnController (wraps MapLibreMapController)
│       ├── internal/
│       │   └── registry.dart            # generic Registry<T> (add/update/remove/clear)
│       ├── theme/
│       │   ├── mapcn_theme.dart         # MapcnTheme tokens from ColorScheme
│       │   └── basemaps.dart            # CARTO style URL selection per brightness
│       ├── markers/
│       │   └── marker.dart              # MarkerId, MarkerOptions, MarkerImage
│       ├── popups/
│       │   ├── popup.dart               # PopupId, PopupOptions
│       │   └── popup_layer.dart         # overlay layer, LatLng→screen projection
│       └── controls/
│           └── controls.dart            # MapcnControls (zoom, compass)
├── example/                             # runnable demo app (iOS + Android)
├── test/
│   ├── basemaps_test.dart
│   ├── registry_test.dart
│   ├── mapcn_theme_test.dart
│   ├── mapcn_controller_camera_test.dart
│   ├── mapcn_controller_markers_test.dart
│   ├── mapcn_controller_popups_test.dart
│   ├── popup_layer_test.dart
│   ├── controls_test.dart
│   └── mapcn_map_test.dart
├── analysis_options.yaml
├── pubspec.yaml
├── CHANGELOG.md
└── README.md
```

## Types & API Contract (locked — keep names identical across all tasks)

These signatures are the source of truth. Every task below must match them exactly.

```dart
// markers/marker.dart
class MarkerId {
  const MarkerId(this.value);
  final int value;
  @override bool operator ==(Object other) => other is MarkerId && other.value == value;
  @override int get hashCode => value.hashCode;
}

class MarkerImage {
  const MarkerImage._(this.assetName, this.size);
  final String assetName;
  final Size size;
  factory MarkerImage.asset(String assetName, {Size size = const Size(32, 32)}) =>
      MarkerImage._(assetName, size);
}

class MarkerOptions {
  const MarkerOptions({
    required this.position,
    this.child,
    this.image,
    this.alignment = Alignment.center,
    this.onTap,
  });
  final LatLng position;
  final Widget? child;        // overlay-widget marker (default path)
  final MarkerImage? image;   // GL-scene symbol (asset path)
  final Alignment alignment;  // anchor: which point of the widget sits on `position`
  final VoidCallback? onTap;
}

// popups/popup.dart
class PopupId {
  const PopupId(this.value);
  final int value;
  @override bool operator ==(Object other) => other is PopupId && other.value == value;
  @override int get hashCode => value.hashCode;
}

class PopupOptions {
  const PopupOptions({
    required this.position,
    required this.child,
    this.alignment = Alignment.bottomCenter,
  });
  final LatLng position;
  final Widget child;
  final Alignment alignment;
}

// internal/registry.dart  — pure, no native deps
class Registry<T> extends ChangeNotifier {
  int add(T value);            // returns new int id
  void update(int id, T v);    // unknown id => no-op
  void remove(int id);         // unknown id => no-op
  void clear();
  Map<int, T> get items;       // unmodifiable snapshot
}

// mapcn_controller.dart
class MapcnController extends ChangeNotifier {
  // Camera
  Future<void> flyTo(LatLng target, {double? zoom});
  Future<void> animateTo(CameraPosition position);
  Future<void> fitBounds(LatLngBounds bounds, {EdgeInsets padding = const EdgeInsets.all(40)});
  Future<void> moveTo(LatLng target, {double? zoom});
  // Markers
  MarkerId addMarker(MarkerOptions options);
  void updateMarker(MarkerId id, MarkerOptions options);  // unknown id => no-op
  void removeMarker(MarkerId id);                          // unknown id => no-op
  void clearMarkers();
  // Popups
  PopupId showPopup(LatLng position, Widget child, {Alignment alignment = Alignment.bottomCenter});
  void hidePopup(PopupId id);                              // unknown id => no-op
  void clearPopups();
}

// theme/mapcn_theme.dart
class MapcnTheme {
  const MapcnTheme({ required markerColor, required popupBackground, required popupBorder,
    required popupRadius, required controlBackground, required controlForeground });
  factory MapcnTheme.fromColorScheme(ColorScheme scheme);
  MapcnTheme copyWith({...});
}

// controls/controls.dart
class MapcnControls {
  const MapcnControls({this.zoom = true, this.compass = true});
  final bool zoom;
  final bool compass;
}

// mapcn_map.dart
class MapcnMap extends StatefulWidget {
  const MapcnMap({ required this.initialCenter, this.initialZoom = 11,
    this.controls = const MapcnControls(), this.theme, required this.onMapReady, super.key });
  final LatLng initialCenter;
  final double initialZoom;
  final MapcnControls controls;
  final MapcnTheme? theme;       // null => derived from Theme.of(context).colorScheme
  final void Function(MapcnController) onMapReady;
}
```

**`maplibre_gl` API used (verified against 0.26.1):**
- `MapLibreMap(initialCameraPosition:, styleString:, compassEnabled:, trackCameraPosition:, onMapCreated:, onStyleLoadedCallback:, onCameraMove:)`
- `MapLibreMapController`: `animateCamera(CameraUpdate)`, `moveCamera(CameraUpdate)`, `addImage(String, Uint8List)`, `addSymbol(SymbolOptions) → Future<Symbol>`, `updateSymbol(Symbol, SymbolOptions)`, `removeSymbol(Symbol)`, `toScreenLocation(LatLng) → Future<Point>`.
- `CameraUpdate.newLatLngZoom`, `.newLatLng`, `.newCameraPosition`, `.newLatLngBounds`, `.zoomIn()`, `.zoomOut()`, `.bearingTo(double)`.
- `CameraPosition(target:, zoom:)`, `LatLng`, `LatLngBounds`, `SymbolOptions(geometry:, iconImage:, iconSize:, iconAnchor:)`.

---

## Task 0: Scaffold the package

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `CHANGELOG.md`, `lib/mapcn.dart`
- Create (generated): `example/` app

- [ ] **Step 1: Create the package scaffold**

Run from the repo root (the directory already exists and holds `docs/`):

```bash
cd /Users/ildebertosilva/labs/mapcn_flutter
flutter create --template=package --org dev.mapcn .
flutter create --template=app --org dev.mapcn --platforms=ios,android example
```

- [ ] **Step 2: Write `pubspec.yaml`**

Replace the generated `pubspec.yaml` with:

```yaml
name: mapcn_flutter
description: Theme-aware, ready-to-use Flutter map components built on maplibre_gl.
version: 0.1.0
repository: https://github.com/ildysilva/mapcn_flutter

environment:
  sdk: ">=3.7.0 <4.0.0"
  flutter: ">=3.22.0"

dependencies:
  flutter:
    sdk: flutter
  maplibre_gl: ^0.26.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4

flutter:
```

- [ ] **Step 3: Write `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    public_member_api_docs: false
    prefer_const_constructors: true
```

- [ ] **Step 4: Write a placeholder `lib/mapcn.dart`**

```dart
library mapcn;

// Public exports are added as each component lands (see Task 12).
```

- [ ] **Step 5: Write `CHANGELOG.md`**

```markdown
# Changelog

## 0.1.0
- Initial v1: themed MapcnMap, MapcnController (camera/markers/popups), zoom + compass controls.
```

- [ ] **Step 6: Resolve deps and verify the project analyzes**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!` (an empty `lib/mapcn.dart` is fine).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold mapcn_flutter package and example app"
```

---

## Task 1: Basemap style selection

**Files:**
- Create: `lib/src/theme/basemaps.dart`
- Test: `test/basemaps_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/basemaps_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/src/theme/basemaps.dart';

void main() {
  test('light brightness selects the positron basemap', () {
    expect(basemapStyleFor(Brightness.light), Basemaps.positron);
    expect(Basemaps.positron, contains('positron'));
  });

  test('dark brightness selects the dark-matter basemap', () {
    expect(basemapStyleFor(Brightness.dark), Basemaps.darkMatter);
    expect(Basemaps.darkMatter, contains('dark-matter'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/basemaps_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mapcn_flutter/src/theme/basemaps.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/theme/basemaps.dart
import 'package:flutter/material.dart' show Brightness;

/// CARTO public vector basemap style URLs (free for dev/demo use; see README).
abstract final class Basemaps {
  static const String positron =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
  static const String darkMatter =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
}

/// Selects the basemap style URL matching the host app's [brightness].
String basemapStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? Basemaps.darkMatter : Basemaps.positron;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/basemaps_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/theme/basemaps.dart test/basemaps_test.dart
git commit -m "feat: basemap style selection by brightness"
```

---

## Task 2: Generic registry

**Files:**
- Create: `lib/src/internal/registry.dart`
- Test: `test/registry_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/src/internal/registry.dart';

void main() {
  test('add returns incrementing ids and stores values', () {
    final r = Registry<String>();
    expect(r.add('a'), 0);
    expect(r.add('b'), 1);
    expect(r.items, {0: 'a', 1: 'b'});
  });

  test('update replaces an existing value', () {
    final r = Registry<String>();
    final id = r.add('a');
    r.update(id, 'z');
    expect(r.items[id], 'z');
  });

  test('update with unknown id is a no-op', () {
    final r = Registry<String>();
    r.update(99, 'z'); // must not throw
    expect(r.items, isEmpty);
  });

  test('remove deletes; unknown id is a no-op', () {
    final r = Registry<String>();
    final id = r.add('a');
    r.remove(id);
    r.remove(99); // must not throw
    expect(r.items, isEmpty);
  });

  test('clear empties the registry', () {
    final r = Registry<String>()..add('a')..add('b');
    r.clear();
    expect(r.items, isEmpty);
  });

  test('items snapshot is unmodifiable', () {
    final r = Registry<String>()..add('a');
    expect(() => r.items[5] = 'x', throwsUnsupportedError);
  });

  test('notifies listeners on mutation only when state changes', () {
    final r = Registry<String>();
    var count = 0;
    r.addListener(() => count++);
    final id = r.add('a'); // +1
    r.update(id, 'b');     // +1
    r.update(99, 'x');     // no change, no notify
    r.remove(99);          // no change, no notify
    r.remove(id);          // +1
    r.clear();             // already empty, no notify
    expect(count, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/registry_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/internal/registry.dart
import 'package:flutter/foundation.dart';

/// In-memory, id-keyed store with change notification. Pure Dart — no native deps.
class Registry<T> extends ChangeNotifier {
  final Map<int, T> _items = <int, T>{};
  int _nextId = 0;

  int add(T value) {
    final int id = _nextId++;
    _items[id] = value;
    notifyListeners();
    return id;
  }

  void update(int id, T value) {
    if (!_items.containsKey(id)) return;
    _items[id] = value;
    notifyListeners();
  }

  void remove(int id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  Map<int, T> get items => Map<int, T>.unmodifiable(_items);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/registry_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/internal/registry.dart test/registry_test.dart
git commit -m "feat: generic id-keyed Registry with no-op semantics"
```

---

## Task 3: Marker model

**Files:**
- Create: `lib/src/markers/marker.dart`
- Test: `test/registry_test.dart` (extend — markers are exercised via the controller in Task 7; here just lock the value types)

- [ ] **Step 1: Write the failing test**

```dart
// test/marker_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/markers/marker.dart';

void main() {
  test('MarkerId equality is by value', () {
    expect(const MarkerId(3), const MarkerId(3));
    expect(const MarkerId(3) == const MarkerId(4), isFalse);
  });

  test('MarkerImage.asset captures name and default size', () {
    final img = MarkerImage.asset('assets/pin.png');
    expect(img.assetName, 'assets/pin.png');
    expect(img.size, const Size(32, 32));
  });

  test('MarkerOptions defaults: center anchor, no child/image/onTap', () {
    const m = MarkerOptions(position: LatLng(1, 2));
    expect(m.position, const LatLng(1, 2));
    expect(m.alignment, Alignment.center);
    expect(m.child, isNull);
    expect(m.image, isNull);
    expect(m.onTap, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/marker_model_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/markers/marker.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [MapcnController.addMarker].
@immutable
class MarkerId {
  const MarkerId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is MarkerId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// An asset image baked into the GL scene as a symbol icon (static, performant
/// for many markers). The default rich-widget path uses [MarkerOptions.child].
@immutable
class MarkerImage {
  const MarkerImage._(this.assetName, this.size);
  final String assetName;
  final Size size;

  factory MarkerImage.asset(String assetName, {Size size = const Size(32, 32)}) =>
      MarkerImage._(assetName, size);
}

/// Describes a marker. Provide [child] for an interactive overlay widget
/// (default) OR [image] for a static GL-scene symbol.
@immutable
class MarkerOptions {
  const MarkerOptions({
    required this.position,
    this.child,
    this.image,
    this.alignment = Alignment.center,
    this.onTap,
  });

  final LatLng position;
  final Widget? child;
  final MarkerImage? image;
  final Alignment alignment;
  final VoidCallback? onTap;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/marker_model_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/markers/marker.dart test/marker_model_test.dart
git commit -m "feat: marker value types (MarkerId, MarkerImage, MarkerOptions)"
```

---

## Task 4: Popup model

**Files:**
- Create: `lib/src/popups/popup.dart`
- Test: `test/popup_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/popup_model_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/popups/popup.dart';

void main() {
  test('PopupId equality is by value', () {
    expect(const PopupId(7), const PopupId(7));
    expect(const PopupId(7) == const PopupId(8), isFalse);
  });

  test('PopupOptions defaults to bottomCenter anchor', () {
    const p = PopupOptions(position: LatLng(1, 2), child: SizedBox());
    expect(p.alignment, Alignment.bottomCenter);
    expect(p.position, const LatLng(1, 2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/popup_model_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/popups/popup.dart
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Opaque handle returned by [MapcnController.showPopup].
@immutable
class PopupId {
  const PopupId(this.value);
  final int value;
  @override
  bool operator ==(Object other) => other is PopupId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Describes a popup overlay anchored to a geographic position.
@immutable
class PopupOptions {
  const PopupOptions({
    required this.position,
    required this.child,
    this.alignment = Alignment.bottomCenter,
  });

  final LatLng position;
  final Widget child;
  final Alignment alignment;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/popup_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/popups/popup.dart test/popup_model_test.dart
git commit -m "feat: popup value types (PopupId, PopupOptions)"
```

---

## Task 5: MapcnTheme token derivation

**Files:**
- Create: `lib/src/theme/mapcn_theme.dart`
- Test: `test/mapcn_theme_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mapcn_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/src/theme/mapcn_theme.dart';

void main() {
  test('fromColorScheme derives tokens from the scheme', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final theme = MapcnTheme.fromColorScheme(scheme);

    expect(theme.markerColor, scheme.primary);
    expect(theme.popupBackground, scheme.surface);
    expect(theme.popupBorder, scheme.outlineVariant);
    expect(theme.controlBackground, scheme.surface);
    expect(theme.controlForeground, scheme.onSurface);
    expect(theme.popupRadius, const Radius.circular(12));
  });

  test('copyWith overrides only the given tokens', () {
    final base = MapcnTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: Colors.indigo));
    final overridden = base.copyWith(markerColor: Colors.red);

    expect(overridden.markerColor, Colors.red);
    expect(overridden.popupBackground, base.popupBackground);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mapcn_theme_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/theme/mapcn_theme.dart
import 'package:flutter/material.dart';

/// Pure data: marker/popup/control styling tokens derived from a [ColorScheme].
/// All fields are overridable via [copyWith] or the [MapcnTheme] constructor.
@immutable
class MapcnTheme {
  const MapcnTheme({
    required this.markerColor,
    required this.popupBackground,
    required this.popupBorder,
    required this.popupRadius,
    required this.controlBackground,
    required this.controlForeground,
  });

  final Color markerColor;
  final Color popupBackground;
  final Color popupBorder;
  final Radius popupRadius;
  final Color controlBackground;
  final Color controlForeground;

  factory MapcnTheme.fromColorScheme(ColorScheme scheme) => MapcnTheme(
        markerColor: scheme.primary,
        popupBackground: scheme.surface,
        popupBorder: scheme.outlineVariant,
        popupRadius: const Radius.circular(12),
        controlBackground: scheme.surface,
        controlForeground: scheme.onSurface,
      );

  MapcnTheme copyWith({
    Color? markerColor,
    Color? popupBackground,
    Color? popupBorder,
    Radius? popupRadius,
    Color? controlBackground,
    Color? controlForeground,
  }) =>
      MapcnTheme(
        markerColor: markerColor ?? this.markerColor,
        popupBackground: popupBackground ?? this.popupBackground,
        popupBorder: popupBorder ?? this.popupBorder,
        popupRadius: popupRadius ?? this.popupRadius,
        controlBackground: controlBackground ?? this.controlBackground,
        controlForeground: controlForeground ?? this.controlForeground,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mapcn_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/theme/mapcn_theme.dart test/mapcn_theme_test.dart
git commit -m "feat: MapcnTheme token derivation from ColorScheme"
```

---

## Task 6: MapcnController — camera methods

The controller wraps the native `MapLibreMapController`. We mock the native one with `mocktail`. This task adds construction + the four camera methods.

**Files:**
- Create: `lib/src/mapcn_controller.dart`
- Create: `test/helpers/mock_native_controller.dart`
- Test: `test/mapcn_controller_camera_test.dart`

- [ ] **Step 1: Write the mock helper + failing test**

```dart
// test/helpers/mock_native_controller.dart
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

class MockMapLibreMapController extends Mock implements MapLibreMapController {}

/// Call once in setUpAll before stubbing methods that take these types.
void registerMapcnFallbacks() {
  registerFallbackValue(CameraUpdate.zoomIn());
  registerFallbackValue(const SymbolOptions());
  registerFallbackValue(const LatLng(0, 0));
  registerFallbackValue(const SymbolOptions()); // for Symbol stubs if needed
}
```

```dart
// test/mapcn_controller_camera_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.animateCamera(any())).thenAnswer((_) async => true);
    when(() => native.moveCamera(any())).thenAnswer((_) async => true);
    controller = MapcnController(native);
  });

  test('flyTo animates to the target with zoom', () async {
    await controller.flyTo(const LatLng(10, 20), zoom: 14);
    verify(() => native.animateCamera(any())).called(1);
    verifyNever(() => native.moveCamera(any()));
  });

  test('moveTo moves the camera without animation', () async {
    await controller.moveTo(const LatLng(10, 20));
    verify(() => native.moveCamera(any())).called(1);
    verifyNever(() => native.animateCamera(any()));
  });

  test('animateTo animates to a full CameraPosition', () async {
    await controller.animateTo(const CameraPosition(target: LatLng(1, 2), zoom: 9));
    verify(() => native.animateCamera(any())).called(1);
  });

  test('fitBounds animates to bounds', () async {
    await controller.fitBounds(
      LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(1, 1)),
    );
    verify(() => native.animateCamera(any())).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mapcn_controller_camera_test.dart`
Expected: FAIL — `mapcn_controller.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mapcn_controller.dart
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

  // Markers and popups are added in Tasks 7 and 8.

  @override
  void dispose() {
    _markers.dispose();
    _popups.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mapcn_controller_camera_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/mapcn_controller.dart test/mapcn_controller_camera_test.dart test/helpers/mock_native_controller.dart
git commit -m "feat: MapcnController camera methods (flyTo/animateTo/fitBounds/moveTo)"
```

---

## Task 7: MapcnController — markers

Adds marker methods. Overlay markers (those with `child`) live only in the registry and are surfaced via `overlayEntries` for the projection layer. Image markers (with `image`) additionally create a native GL symbol via `addSymbol`.

**Files:**
- Modify: `lib/src/mapcn_controller.dart`
- Test: `test/mapcn_controller_markers_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mapcn_controller_markers_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/markers/marker.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

class _FakeSymbol extends Fake implements Symbol {}

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.addImage(any(), any())).thenAnswer((_) async {});
    when(() => native.addSymbol(any())).thenAnswer((_) async => _FakeSymbol());
    when(() => native.removeSymbol(any())).thenAnswer((_) async {});
    controller = MapcnController(native);
  });

  test('addMarker with child returns an id and exposes an overlay entry', () {
    final id = controller.addMarker(
      const MarkerOptions(position: LatLng(1, 2), child: Text('hi')),
    );
    expect(id, const MarkerId(0));
    expect(controller.overlayEntries.length, 1);
    expect(controller.overlayEntries.single.position, const LatLng(1, 2));
  });

  test('addMarker with image creates a GL symbol, no overlay entry', () async {
    controller.addMarker(
      MarkerOptions(position: const LatLng(1, 2), image: MarkerImage.asset('a.png')),
    );
    await Future<void>.delayed(Duration.zero); // let async symbol creation run
    verify(() => native.addImage(any(), any())).called(1);
    verify(() => native.addSymbol(any())).called(1);
    expect(controller.overlayEntries, isEmpty);
  });

  test('removeMarker with unknown id is a no-op', () {
    controller.removeMarker(const MarkerId(99)); // must not throw
    expect(controller.overlayEntries, isEmpty);
  });

  test('updateMarker replaces options for an existing child marker', () {
    final id = controller.addMarker(
      const MarkerOptions(position: LatLng(1, 2), child: Text('a')),
    );
    controller.updateMarker(id, const MarkerOptions(position: LatLng(3, 4), child: Text('b')));
    expect(controller.overlayEntries.single.position, const LatLng(3, 4));
  });

  test('clearMarkers empties overlay entries and removes GL symbols', () async {
    controller.addMarker(const MarkerOptions(position: LatLng(1, 2), child: Text('a')));
    controller.addMarker(
      MarkerOptions(position: const LatLng(3, 4), image: MarkerImage.asset('a.png')),
    );
    await Future<void>.delayed(Duration.zero);
    controller.clearMarkers();
    await Future<void>.delayed(Duration.zero);
    expect(controller.overlayEntries, isEmpty);
    verify(() => native.removeSymbol(any())).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mapcn_controller_markers_test.dart`
Expected: FAIL — `addMarker`/`overlayEntries` not defined.

- [ ] **Step 3: Write minimal implementation**

Add the asset-loading import at the top of `lib/src/mapcn_controller.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
```

Add an overlay-entry value type at the bottom of the file (outside the class):

```dart
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
```

Inside `MapcnController`, add the symbol bookkeeping field and the marker methods (replace the `// Markers and popups...` comment):

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mapcn_controller_markers_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/mapcn_controller.dart test/mapcn_controller_markers_test.dart
git commit -m "feat: MapcnController marker registry + GL symbol path"
```

---

## Task 8: MapcnController — popups

**Files:**
- Modify: `lib/src/mapcn_controller.dart`
- Test: `test/mapcn_controller_popups_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/mapcn_controller_popups_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mapcn_flutter/src/markers/marker.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnController controller;

  setUp(() {
    native = MockMapLibreMapController();
    controller = MapcnController(native);
  });

  test('showPopup returns an id and appends an overlay entry', () {
    final id = controller.showPopup(const LatLng(1, 2), const Text('hello'));
    expect(id, const PopupId(0));
    expect(controller.overlayEntries.length, 1);
    expect(controller.overlayEntries.single.alignment, Alignment.bottomCenter);
  });

  test('hidePopup removes the entry; unknown id is a no-op', () {
    final id = controller.showPopup(const LatLng(1, 2), const Text('hello'));
    controller.hidePopup(const PopupId(99)); // no-op
    expect(controller.overlayEntries.length, 1);
    controller.hidePopup(id);
    expect(controller.overlayEntries, isEmpty);
  });

  test('overlayEntries merges child-markers and popups', () {
    controller.addMarker(const MarkerOptions(position: LatLng(0, 0), child: Text('m')));
    controller.showPopup(const LatLng(1, 1), const Text('p'));
    expect(controller.overlayEntries.length, 2);
  });

  test('clearPopups empties popups but keeps markers', () {
    controller.addMarker(const MarkerOptions(position: LatLng(0, 0), child: Text('m')));
    controller.showPopup(const LatLng(1, 1), const Text('p'));
    controller.clearPopups();
    expect(controller.overlayEntries.length, 1);
  });
}
```

Note: import `PopupId` — add `export 'popups/popup.dart' show PopupId, PopupOptions;`? No. The test imports `PopupId` from `mapcn_controller.dart`; add `import 'popups/popup.dart';` is already in the controller but `PopupId` must be visible to the test. The controller file already imports it; re-export it for ergonomics by adding to the controller file: `export 'popups/popup.dart' show PopupId, PopupOptions;`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mapcn_controller_popups_test.dart`
Expected: FAIL — `showPopup` not defined.

- [ ] **Step 3: Write minimal implementation**

Add a re-export near the top of `lib/src/mapcn_controller.dart` (after the imports):

```dart
export 'popups/popup.dart' show PopupId, PopupOptions;
export 'markers/marker.dart' show MarkerId, MarkerImage, MarkerOptions;
```

Add the popup methods inside `MapcnController` (after the marker methods):

```dart
  // --- Popups -------------------------------------------------------------

  PopupId showPopup(
    LatLng position,
    Widget child, {
    Alignment alignment = Alignment.bottomCenter,
  }) {
    final int id = _popups.add(
      PopupOptions(position: position, child: child, alignment: alignment),
    );
    return PopupId(id);
  }

  void hidePopup(PopupId id) => _popups.remove(id.value);

  void clearPopups() => _popups.clear();
```

Extend `overlayEntries` to append popups. Replace the getter body with:

```dart
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
        for (final entry in _popups.items.entries)
          OverlayEntryData(
            key: PopupId(entry.key),
            position: entry.value.position,
            alignment: entry.value.alignment,
            child: entry.value.child,
          ),
      ];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mapcn_controller_popups_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/mapcn_controller.dart test/mapcn_controller_popups_test.dart
git commit -m "feat: MapcnController popup registry + merged overlay entries"
```

---

## Task 9: Overlay projection layer

A `StatefulWidget` that, given the native controller and the list of `OverlayEntryData`, projects each `LatLng` to a screen `Offset` via `toScreenLocation` and positions the child. Re-projects when `cameraVersion` changes (driven by `MapcnMap`'s `onCameraMove`).

**Files:**
- Create: `lib/src/popups/popup_layer.dart`
- Test: `test/popup_layer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/popup_layer_test.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mapcn_flutter/src/popups/popup_layer.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  testWidgets('positions an overlay entry at the projected screen offset',
      (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(120, 240));

    final entries = [
      OverlayEntryData(
        key: const ValueKey('p'),
        position: const LatLng(1, 2),
        alignment: Alignment.topLeft, // zero anchor translation -> exact offset
        child: const SizedBox(key: ValueKey('child'), width: 10, height: 10),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        MapcnOverlayLayer(native: native, entries: entries, cameraVersion: 0),
      ]),
    ));
    await tester.pumpAndSettle();

    final pos = tester.getTopLeft(find.byKey(const ValueKey('child')));
    expect(pos.dx, moreOrLessEquals(120, epsilon: 0.5));
    expect(pos.dy, moreOrLessEquals(240, epsilon: 0.5));
  });

  testWidgets('invokes onTap when the overlay child is tapped', (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(50, 50));
    var tapped = false;

    final entries = [
      OverlayEntryData(
        key: const ValueKey('m'),
        position: const LatLng(0, 0),
        alignment: Alignment.topLeft,
        onTap: () => tapped = true,
        child: const SizedBox(key: ValueKey('hit'), width: 40, height: 40),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        MapcnOverlayLayer(native: native, entries: entries, cameraVersion: 0),
      ]),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hit')));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/popup_layer_test.dart`
Expected: FAIL — `popup_layer.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/popups/popup_layer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../mapcn_controller.dart' show OverlayEntryData;

/// Projects geographically-anchored overlay entries onto screen offsets and
/// positions each in the enclosing [Stack]. Re-projects whenever [entries] or
/// [cameraVersion] changes. Off-screen entries are placed far out of view
/// rather than removed, to avoid flicker during gestures.
class MapcnOverlayLayer extends StatefulWidget {
  const MapcnOverlayLayer({
    required this.native,
    required this.entries,
    required this.cameraVersion,
    super.key,
  });

  final MapLibreMapController native;
  final List<OverlayEntryData> entries;
  final int cameraVersion;

  @override
  State<MapcnOverlayLayer> createState() => _MapcnOverlayLayerState();
}

class _MapcnOverlayLayerState extends State<MapcnOverlayLayer> {
  Map<Object, Offset> _offsets = <Object, Offset>{};

  @override
  void initState() {
    super.initState();
    _reproject();
  }

  @override
  void didUpdateWidget(MapcnOverlayLayer old) {
    super.didUpdateWidget(old);
    if (old.cameraVersion != widget.cameraVersion ||
        old.entries != widget.entries) {
      _reproject();
    }
  }

  Future<void> _reproject() async {
    final next = <Object, Offset>{};
    for (final e in widget.entries) {
      final Point<num> p = await widget.native.toScreenLocation(e.position);
      next[e.key] = Offset(p.x.toDouble(), p.y.toDouble());
    }
    if (mounted) setState(() => _offsets = next);
  }

  // Fraction of child size to shift so [alignment] sits on the screen offset.
  Offset _anchorFraction(Alignment a) => Offset(-(a.x + 1) / 2, -(a.y + 1) / 2);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final e in widget.entries)
          if (_offsets.containsKey(e.key))
            Positioned(
              left: _offsets[e.key]!.dx,
              top: _offsets[e.key]!.dy,
              child: FractionalTranslation(
                translation: _anchorFraction(e.alignment),
                child: e.onTap == null
                    ? e.child
                    : GestureDetector(onTap: e.onTap, child: e.child),
              ),
            ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/popup_layer_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/popups/popup_layer.dart test/popup_layer_test.dart
git commit -m "feat: overlay projection layer (LatLng -> screen, anchor, onTap)"
```

---

## Task 10: Controls widget

`MapcnControls` is a config struct (already in the Types contract). This task builds the **rendered** controls widget that calls the native controller for zoom and bearing reset, styled via `MapcnTheme`.

**Files:**
- Create: `lib/src/controls/controls.dart`
- Test: `test/controls_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/controls_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/controls/controls.dart';
import 'package:mapcn_flutter/src/theme/mapcn_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  late MockMapLibreMapController native;
  late MapcnTheme theme;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.animateCamera(any())).thenAnswer((_) async => true);
    theme = MapcnTheme.fromColorScheme(ColorScheme.fromSeed(seedColor: Colors.blue));
  });

  Future<void> pump(WidgetTester tester, MapcnControls config) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MapcnControlsView(native: native, config: config, theme: theme),
        ),
      ));

  testWidgets('zoom in/out buttons call animateCamera', (tester) async {
    await pump(tester, const MapcnControls(zoom: true, compass: false));
    await tester.tap(find.byKey(const ValueKey('mapcn_zoom_in')));
    await tester.tap(find.byKey(const ValueKey('mapcn_zoom_out')));
    verify(() => native.animateCamera(any())).called(2);
  });

  testWidgets('compass button resets bearing', (tester) async {
    await pump(tester, const MapcnControls(zoom: false, compass: true));
    await tester.tap(find.byKey(const ValueKey('mapcn_compass')));
    verify(() => native.animateCamera(any())).called(1);
  });

  testWidgets('hidden controls are not rendered', (tester) async {
    await pump(tester, const MapcnControls(zoom: false, compass: false));
    expect(find.byKey(const ValueKey('mapcn_zoom_in')), findsNothing);
    expect(find.byKey(const ValueKey('mapcn_compass')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls_test.dart`
Expected: FAIL — `controls.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/controls/controls.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../theme/mapcn_theme.dart';

/// Declares which on-map controls are shown. Fullscreen and locate are out of
/// scope for v1 (see design spec).
@immutable
class MapcnControls {
  const MapcnControls({this.zoom = true, this.compass = true});
  final bool zoom;
  final bool compass;
}

/// Renders the configured controls and wires them to the native controller.
class MapcnControlsView extends StatelessWidget {
  const MapcnControlsView({
    required this.native,
    required this.config,
    required this.theme,
    super.key,
  });

  final MapLibreMapController native;
  final MapcnControls config;
  final MapcnTheme theme;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.zoom) ...[
            _button(
              key: const ValueKey('mapcn_zoom_in'),
              icon: Icons.add,
              onTap: () => native.animateCamera(CameraUpdate.zoomIn()),
            ),
            const SizedBox(height: 8),
            _button(
              key: const ValueKey('mapcn_zoom_out'),
              icon: Icons.remove,
              onTap: () => native.animateCamera(CameraUpdate.zoomOut()),
            ),
          ],
          if (config.zoom && config.compass) const SizedBox(height: 8),
          if (config.compass)
            _button(
              key: const ValueKey('mapcn_compass'),
              icon: Icons.explore_outlined,
              onTap: () => native.animateCamera(CameraUpdate.bearingTo(0)),
            ),
        ],
      ),
    );
  }

  Widget _button({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: theme.controlBackground,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: theme.controlForeground),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/controls/controls.dart test/controls_test.dart
git commit -m "feat: MapcnControls view (zoom in/out, compass reset-bearing)"
```

---

## Task 11: MapcnMap widget

Assembles the `Stack`: native `MapLibreMap` (style from brightness) + overlay layer + controls. Creates the `MapcnController` on map-create, calls `onMapReady` once after the first style load, re-projects overlays on camera move, and re-applies the style + GL symbols when the host theme's brightness changes.

**Files:**
- Create: `lib/src/mapcn_map.dart`
- Test: `test/mapcn_map_test.dart`

- [ ] **Step 1: Write the failing widget test**

Native rendering can't run in a widget test, so the test injects a fake map builder that synchronously yields a mocked native controller and fires the lifecycle callbacks. The `MapcnMap` exposes a `@visibleForTesting` builder seam for this.

```dart
// test/mapcn_map_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mapcn_flutter/src/mapcn_controller.dart';
import 'package:mapcn_flutter/src/mapcn_map.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerMapcnFallbacks);

  testWidgets('builds a Stack with controls and calls onMapReady once',
      (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(0, 0));
    MapcnController? ready;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: MapcnMap(
        initialCenter: const LatLng(0, 0),
        controls: const MapcnControls(zoom: true, compass: true),
        onMapReady: (c) => ready = c,
        mapBuilder: testMapBuilder(native), // injects fake native + fires lifecycle
      ),
    ));
    await tester.pumpAndSettle();

    expect(ready, isNotNull);
    expect(find.byKey(const ValueKey('mapcn_zoom_in')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapcn_compass')), findsOneWidget);
  });

  testWidgets('selects positron in light mode', (tester) async {
    final native = MockMapLibreMapController();
    when(() => native.toScreenLocation(any()))
        .thenAnswer((_) async => const Point<num>(0, 0));
    String? capturedStyle;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: MapcnMap(
        initialCenter: const LatLng(0, 0),
        onMapReady: (_) {},
        mapBuilder: testMapBuilder(native, onStyle: (s) => capturedStyle = s),
      ),
    ));
    await tester.pumpAndSettle();
    expect(capturedStyle, contains('positron'));
  });
}
```

Helper for the test seam (add to `test/helpers/mock_native_controller.dart`):

```dart
import 'package:flutter/widgets.dart';
import 'package:mapcn_flutter/src/mapcn_map.dart';

/// Builds a fake map: ignores rendering, immediately invokes onMapCreated and
/// onStyleLoaded with [native], and reports the chosen style string.
MapcnMapBuilder testMapBuilder(
  MapLibreMapController native, {
  void Function(String style)? onStyle,
}) {
  return ({
    required String styleString,
    required CameraPosition initialCameraPosition,
    required void Function(MapLibreMapController) onMapCreated,
    required void Function() onStyleLoaded,
    required void Function(CameraPosition) onCameraMove,
  }) {
    onStyle?.call(styleString);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onMapCreated(native);
      onStyleLoaded();
    });
    return const SizedBox.expand();
  };
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mapcn_map_test.dart`
Expected: FAIL — `mapcn_map.dart` / `MapcnMapBuilder` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/mapcn_map.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'controls/controls.dart';
import 'mapcn_controller.dart';
import 'popups/popup_layer.dart';
import 'theme/basemaps.dart';
import 'theme/mapcn_theme.dart';

export 'controls/controls.dart' show MapcnControls;

/// Test seam: builds the native map view. Production uses [_defaultMapBuilder].
typedef MapcnMapBuilder = Widget Function({
  required String styleString,
  required CameraPosition initialCameraPosition,
  required void Function(MapLibreMapController) onMapCreated,
  required void Function() onStyleLoaded,
  required void Function(CameraPosition) onCameraMove,
});

/// A theme-aware map with overlay markers/popups and zoom/compass controls.
class MapcnMap extends StatefulWidget {
  const MapcnMap({
    required this.initialCenter,
    required this.onMapReady,
    this.initialZoom = 11,
    this.controls = const MapcnControls(),
    this.theme,
    @visibleForTesting this.mapBuilder = _defaultMapBuilder,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final MapcnControls controls;
  final MapcnTheme? theme;
  final void Function(MapcnController) onMapReady;
  final MapcnMapBuilder mapBuilder;

  @override
  State<MapcnMap> createState() => _MapcnMapState();
}

class _MapcnMapState extends State<MapcnMap> {
  MapLibreMapController? _native;
  MapcnController? _controller;
  int _cameraVersion = 0;
  bool _readyCalled = false;

  void _onMapCreated(MapLibreMapController native) {
    _native = native;
    _controller = MapcnController(native)..addListener(_onOverlayChanged);
  }

  void _onOverlayChanged() => setState(() {});

  void _onStyleLoaded() {
    if (!_readyCalled) {
      _readyCalled = true;
      widget.onMapReady(_controller!);
    } else {
      // Theme changed mid-session: GL symbols must be re-applied to the new style.
      _controller!.reapplySymbols();
    }
  }

  void _onCameraMove(CameraPosition _) =>
      setState(() => _cameraVersion++);

  @override
  void dispose() {
    _controller?.removeListener(_onOverlayChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.theme ?? MapcnTheme.fromColorScheme(scheme);
    final style = basemapStyleFor(Theme.of(context).brightness);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.mapBuilder(
          styleString: style,
          initialCameraPosition: CameraPosition(
            target: widget.initialCenter,
            zoom: widget.initialZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoaded: _onStyleLoaded,
          onCameraMove: _onCameraMove,
        ),
        if (_native != null && _controller != null)
          MapcnOverlayLayer(
            native: _native!,
            entries: _controller!.overlayEntries,
            cameraVersion: _cameraVersion,
          ),
        if (_native != null)
          MapcnControlsView(
            native: _native!,
            config: widget.controls,
            theme: theme,
          ),
      ],
    );
  }
}

Widget _defaultMapBuilder({
  required String styleString,
  required CameraPosition initialCameraPosition,
  required void Function(MapLibreMapController) onMapCreated,
  required void Function() onStyleLoaded,
  required void Function(CameraPosition) onCameraMove,
}) {
  return MapLibreMap(
    styleString: styleString,
    initialCameraPosition: initialCameraPosition,
    trackCameraPosition: true,
    compassEnabled: false, // we render our own compass control
    onMapCreated: onMapCreated,
    onStyleLoadedCallback: onStyleLoaded,
    onCameraMove: onCameraMove,
  );
}
```

- [ ] **Step 4: Add `reapplySymbols()` to the controller**

In `lib/src/mapcn_controller.dart`, add inside `MapcnController` (after `clearMarkers`):

```dart
  /// Re-creates GL symbols on a freshly loaded style (e.g. after a theme
  /// change). Overlay-widget markers and popups need no re-application — they
  /// are Flutter widgets, not part of the GL scene.
  void reapplySymbols() {
    _symbols.clear();
    for (final entry in _markers.items.entries) {
      if (entry.value.image != null) {
        _createSymbol(entry.key, entry.value);
      }
    }
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/mapcn_map_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/mapcn_map.dart lib/src/mapcn_controller.dart test/mapcn_map_test.dart test/helpers/mock_native_controller.dart
git commit -m "feat: MapcnMap widget (themed Stack, lifecycle, style reload)"
```

---

## Task 12: Public API exports

**Files:**
- Modify: `lib/mapcn.dart`
- Test: `test/exports_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/exports_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/mapcn.dart';

void main() {
  test('public surface is exported', () {
    // Compile-time check: referencing these confirms they are exported.
    expect(MapcnMap, isNotNull);
    expect(MapcnControls, isNotNull);
    expect(MapcnTheme, isNotNull);
    expect(MapcnController, isNotNull);
    expect(MarkerOptions, isNotNull);
    expect(MarkerImage, isNotNull);
    expect(MarkerId, isNotNull);
    expect(PopupId, isNotNull);
    expect(LatLng, isNotNull);        // re-exported from maplibre_gl
    expect(LatLngBounds, isNotNull);  // re-exported from maplibre_gl
    expect(CameraPosition, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/exports_test.dart`
Expected: FAIL — undefined names (e.g. `MapcnMap`).

- [ ] **Step 3: Write the exports**

```dart
// lib/mapcn.dart
library mapcn;

export 'src/controls/controls.dart' show MapcnControls;
export 'src/mapcn_controller.dart'
    show MapcnController, MarkerId, MarkerImage, MarkerOptions, PopupId, PopupOptions;
export 'src/mapcn_map.dart' show MapcnMap;
export 'src/theme/basemaps.dart' show Basemaps;
export 'src/theme/mapcn_theme.dart' show MapcnTheme;

// Re-export the geographic primitives users need so they don't have to add a
// separate maplibre_gl import for the common case.
export 'package:maplibre_gl/maplibre_gl.dart'
    show LatLng, LatLngBounds, CameraPosition;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/exports_test.dart && flutter analyze`
Expected: PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/mapcn.dart test/exports_test.dart
git commit -m "feat: public API exports"
```

---

## Task 13: Example app

Wire the example app to demonstrate markers, a popup, camera control, and a theme toggle on real devices.

**Files:**
- Modify: `example/pubspec.yaml`, `example/lib/main.dart`
- Modify: `example/ios/Podfile` (platform min), `example/android/app/build.gradle` (minSdk)

- [ ] **Step 1: Add the package dependency to the example**

In `example/pubspec.yaml`, under `dependencies:` add:

```yaml
  mapcn_flutter:
    path: ../
```

- [ ] **Step 2: Set native platform minimums required by `maplibre_gl`**

In `example/ios/Podfile`, ensure the first non-comment line is:

```ruby
platform :ios, '13.0'
```

In `example/android/app/build.gradle`, inside `defaultConfig`, set:

```gradle
minSdkVersion 21
```

- [ ] **Step 3: Write the demo `example/lib/main.dart`**

```dart
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
```

- [ ] **Step 4: Verify the example resolves and analyzes**

Run: `cd example && flutter pub get && flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 5: Manual smoke test (real device or simulator)**

Run: `cd example && flutter run`
Verify: map loads with positron style; tapping the marker shows the popup; zoom/compass buttons work; toggling the app-bar brightness switches the basemap to dark-matter and the marker/popup re-anchor correctly.

- [ ] **Step 6: Commit**

```bash
git add example/
git commit -m "feat: example app (markers, popup, camera, theme toggle)"
```

---

## Task 14: Docs + finalize

**Files:**
- Modify: `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# mapcn_flutter

Theme-aware, ready-to-use Flutter map components built on
[`maplibre_gl`](https://pub.dev/packages/maplibre_gl). iOS and Android.

## Install

```yaml
dependencies:
  mapcn_flutter: ^0.1.0
```

## Platform setup

`maplibre_gl` requires iOS 13+ and Android `minSdkVersion 21`.

## Usage

```dart
import 'package:mapcn_flutter/mapcn.dart';

MapcnMap(
  initialCenter: const LatLng(37.77, -122.42),
  initialZoom: 11,
  controls: const MapcnControls(zoom: true, compass: true),
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
production use and supply your own style URL via a custom `MapcnTheme`/basemap
if required.

## License

MIT
````

- [ ] **Step 2: Confirm the dependency pin**

`pubspec.yaml` already pins `maplibre_gl: ^0.26.1` (Task 0). Confirm it resolved by running `flutter pub deps | grep maplibre_gl` — expect `maplibre_gl 0.26.x`.

- [ ] **Step 3: Run the full test suite + analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests PASS; `No issues found!`.

- [ ] **Step 4: Dry-run package publish validation**

Run: `flutter pub publish --dry-run`
Expected: no errors blocking publish (warnings about repository/homepage are acceptable for now). Fix any reported missing files (e.g. `LICENSE`).

- [ ] **Step 5: Add a `LICENSE` if publish dry-run requires it**

Create `LICENSE` (MIT, author `ildysilva`) if the dry-run flags it missing, then re-run Step 4.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md LICENSE
git commit -m "docs: README, license, and v1 finalization"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| pub.dev package layout | 0, 12 |
| Theme-aware basemap (positron/dark-matter) | 1, 11 |
| `MapcnTheme` token derivation, overridable | 5 |
| `MapcnMap` Stack (map + overlay + controls), `onMapReady` | 11 |
| `MapcnController` camera (flyTo/animateTo/fitBounds/moveTo) | 6 |
| Markers: overlay (default) + GL-symbol (asset image) | 3, 7 |
| Popups: overlay projection | 4, 8, 9 |
| Marker/popup registries, unknown-id no-ops | 2, 7, 8 |
| Controls (zoom + compass/reset-bearing) | 10 |
| Pre-ready safety (controller only via onMapReady) | 11 |
| Style reload race (re-apply symbols after restyle) | 11 |
| Off-screen overlays positioned out of view, not removed | 9 |
| Unit tests (theme/registry/basemap) | 1, 2, 5 |
| Widget tests (Stack/controls/popup projection) | 9, 10, 11 |
| Example app integration surface | 13 |
| Pin `maplibre_gl`, basemap terms note | 0, 14 |

**Open spec item:** package name `mapcn` vs `mapcn_flutter` — this plan uses `mapcn_flutter` (directory and pub name aligned). If `mapcn` is available and preferred, change `name:` in `pubspec.yaml` (Task 0) and the `library` directive (Task 12) before first publish; nothing else depends on the package name.

**Deferred per spec (`widget_to_image.dart`):** `MarkerImage.widget` snapshot path is intentionally not in this plan (see Scope Notes). The default overlay-widget marker covers rich-widget rendering.

**Type consistency:** `MarkerId`/`PopupId`/`MarkerOptions`/`PopupOptions`/`OverlayEntryData`/`MapcnController` method names are defined once in the Types contract and reused verbatim across Tasks 3–12. The overlay layer widget is named `MapcnOverlayLayer` (Task 9) and referenced under that name in Task 11.
```
