# MapcnGlobe Phase 0 — GPU Sphere Spike — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Prove the `flutter_gpu` path: render a static-textured UV sphere with an orbit camera and drag-to-rotate, on a real device — the go/no-go gate for Phases 1–4. Establish the pure-Dart math foundation (sphere coords, camera matrix, mesh) with full unit tests.

**Architecture:** Pure-Dart `sphere_math` + `globe_camera` + `sphere_mesh` (unit-tested, no GPU) feed a `GlobeRenderer` that quarantines all `flutter_gpu` calls. A minimal `MapcnGlobe` widget hosts the render loop and gestures. Verification of the GPU draw itself is a manual on-device step (the spike's purpose).

**Tech Stack:** Dart/Flutter, `flutter_gpu` (SDK, experimental, Impeller-only), `flutter_gpu_shaders` (shader bundle build hook), `vector_math`.

**Verification note:** `flutter_gpu` rendering requires Impeller on a device/simulator and cannot run in headless `flutter test`. Tasks 1–3 are fully unit-tested. Tasks 4–7 are authored code whose verification step is `flutter run` on a device (clearly marked). This is expected for a GPU spike.

---

## File Structure (Phase 0)

```
lib/src/globe/
  sphere_math.dart      # latLngToUnitSphere, projectToScreen, isFrontFacing
  globe_camera.dart     # GlobeCamera, cameraDistance, eyePosition, viewProjection
  sphere_mesh.dart      # SphereMesh: interleaved vertices (pos+uv) + indices
  globe_renderer.dart   # GlobeRenderer (flutter_gpu) [device-gated]
  mapcn_globe.dart      # minimal MapcnGlobe widget (Texture + Ticker + drag) [partly device-gated]
shaders/
  globe.vert           # GLSL ES vertex shader
  globe.frag           # GLSL ES fragment shader
  globe.shaderbundle.json
test/globe/
  sphere_math_test.dart
  globe_camera_test.dart
  sphere_mesh_test.dart
  mapcn_globe_test.dart
```

---

## Task 1: Sphere coordinate math

**Files:**
- Create: `lib/src/globe/sphere_math.dart`
- Test: `test/globe/sphere_math_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/globe/sphere_math_test.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart' show Vector3, Matrix4;
import 'package:mapcn_flutter/src/globe/sphere_math.dart';

void main() {
  test('lat/lng 0,0 maps to +X axis on the unit sphere', () {
    final v = latLngToUnitSphere(const LatLng(0, 0));
    expect(v.x, closeTo(1, 1e-9));
    expect(v.y, closeTo(0, 1e-9));
    expect(v.z, closeTo(0, 1e-9));
    expect(v.length, closeTo(1, 1e-9));
  });

  test('north pole maps to +Y', () {
    final v = latLngToUnitSphere(const LatLng(90, 0));
    expect(v.y, closeTo(1, 1e-9));
    expect(v.length, closeTo(1, 1e-9));
  });

  test('lng 90 maps to +Z', () {
    final v = latLngToUnitSphere(const LatLng(0, 90));
    expect(v.z, closeTo(1, 1e-9));
  });

  test('isFrontFacing: point under the camera is visible, antipode is not', () {
    final cam = Vector3(3, 0, 0); // camera out along +X
    expect(isFrontFacing(Vector3(1, 0, 0), cam), isTrue);
    expect(isFrontFacing(Vector3(-1, 0, 0), cam), isFalse);
  });

  test('projectToScreen puts a point in front near the requested viewport', () {
    // Identity-ish: a point at origin projected with a trivial matrix.
    final mvp = Matrix4.identity();
    final p = projectToScreen(Vector3(0, 0, 0), mvp, const Size(200, 100));
    expect(p, isNotNull);
    expect(p!.dx, closeTo(100, 1e-6)); // ndc 0 -> center x
    expect(p.dy, closeTo(50, 1e-6));
  });

  test('projectToScreen returns null for a point behind the camera (w<=0)', () {
    // A perspective-like matrix that pushes z behind: use w from a clip transform.
    final mvp = Matrix4.zero()
      ..setEntry(3, 2, -1) // w = -z
      ..setEntry(0, 0, 1)
      ..setEntry(1, 1, 1)
      ..setEntry(2, 2, 1);
    final behind = projectToScreen(Vector3(0, 0, 1), mvp, const Size(200, 100));
    expect(behind, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/globe/sphere_math_test.dart`
Expected: FAIL — `sphere_math.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/globe/sphere_math.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart' show Vector3, Matrix4;

/// Maps a geographic coordinate to a point on the unit sphere.
/// lat/lng (0,0) -> +X, north pole -> +Y, lng +90 -> +Z.
Vector3 latLngToUnitSphere(LatLng ll) {
  final lat = ll.latitude * math.pi / 180.0;
  final lng = ll.longitude * math.pi / 180.0;
  final cosLat = math.cos(lat);
  return Vector3(cosLat * math.cos(lng), math.sin(lat), cosLat * math.sin(lng));
}

/// True if a unit-sphere [point] is on the hemisphere facing [cameraPosition]
/// (i.e. in front of the globe's horizon, not occluded by the globe body).
bool isFrontFacing(Vector3 point, Vector3 cameraPosition) {
  final camLen = cameraPosition.length;
  if (camLen <= 1.0) return true; // inside/at surface: treat as visible
  // Horizon plane: dot(point, camDir) must exceed 1/|cam|.
  final camDir = cameraPosition / camLen;
  return point.dot(camDir) > 1.0 / camLen;
}

/// Projects a world-space [point] through [viewProjection] to a screen offset
/// within [viewport]. Returns null if the point is behind the camera (w <= 0).
Offset? projectToScreen(Vector3 point, Matrix4 viewProjection, Size viewport) {
  final v = viewProjection.transform(_v4(point));
  if (v.w <= 0) return null;
  final ndcX = v.x / v.w;
  final ndcY = v.y / v.w;
  return Offset(
    (ndcX * 0.5 + 0.5) * viewport.width,
    (1.0 - (ndcY * 0.5 + 0.5)) * viewport.height,
  );
}

// Local 4-vector helper (avoids importing Vector4 at call sites).
_V4 _v4(Vector3 p) => _V4(p.x, p.y, p.z, 1);
```

Note: `Matrix4.transform` needs a `Vector4`. Replace the helper with the real type:

```dart
// at top, add: import 'package:vector_math/vector_math.dart' show Vector3, Vector4, Matrix4;
// and replace _v4/_V4 usage:
Offset? projectToScreen(Vector3 point, Matrix4 viewProjection, Size viewport) {
  final v = viewProjection.transform(Vector4(point.x, point.y, point.z, 1));
  if (v.w <= 0) return null;
  final ndcX = v.x / v.w;
  final ndcY = v.y / v.w;
  return Offset(
    (ndcX * 0.5 + 0.5) * viewport.width,
    (1.0 - (ndcY * 0.5 + 0.5)) * viewport.height,
  );
}
```

(Delete the `_v4`/`_V4` placeholder lines; they exist only to show the intent.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/globe/sphere_math_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/globe/sphere_math.dart test/globe/sphere_math_test.dart
git commit -m "feat(globe): sphere coordinate + projection + occlusion math"
```

---

## Task 2: Orbit camera

**Files:**
- Create: `lib/src/globe/globe_camera.dart`
- Test: `test/globe/globe_camera_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/globe/globe_camera_test.dart
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/globe/globe_camera.dart';
import 'package:mapcn_flutter/src/globe/sphere_math.dart';

void main() {
  test('cameraDistance decreases as zoom increases (zoom in = closer)', () {
    expect(cameraDistance(4) < cameraDistance(1), isTrue);
    expect(cameraDistance(1) > 1.0, isTrue); // always outside the unit sphere
  });

  test('eye sits outside the sphere along the center normal', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2);
    final eye = cam.eyePosition();
    expect(eye.length, greaterThan(1.0));
    expect(eye.x, greaterThan(0)); // center 0,0 -> +X
  });

  test('the camera center projects to the middle of the viewport', () {
    const cam = GlobeCamera(center: LatLng(10, 20), zoom: 2);
    const size = Size(400, 400);
    final mvp = cam.viewProjection(size);
    final screen = projectToScreen(latLngToUnitSphere(cam.center), mvp, size);
    expect(screen, isNotNull);
    expect(screen!.dx, closeTo(200, 2));
    expect(screen.dy, closeTo(200, 2));
  });

  test('the antipodal point is behind the globe and projects but is occluded', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2);
    final back = latLngToUnitSphere(const LatLng(0, 180));
    expect(isFrontFacing(back, cam.eyePosition()), isFalse);
  });

  test('copyWith overrides only the given fields', () {
    const cam = GlobeCamera(center: LatLng(0, 0), zoom: 2, bearing: 0);
    final c2 = cam.copyWith(zoom: 5);
    expect(c2.zoom, 5);
    expect(c2.center, cam.center);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/globe/globe_camera_test.dart`
Expected: FAIL — `globe_camera.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/globe/globe_camera.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart' show Size;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:vector_math/vector_math.dart' show Vector3, Matrix4;

import 'sphere_math.dart';

/// Distance of the camera from the globe centre for a given [zoom].
/// Monotonically decreasing in zoom; always > 1 (outside the unit sphere).
double cameraDistance(double zoom) => 1.1 + 6.0 * math.pow(0.5, zoom).toDouble();

/// Orbit-camera state. v1 spike uses bearing/tilt = 0; fields exist for later.
class GlobeCamera {
  const GlobeCamera({
    required this.center,
    this.zoom = 2,
    this.bearing = 0,
    this.tilt = 0,
  });

  final LatLng center;
  final double zoom;
  final double bearing;
  final double tilt;

  Vector3 eyePosition() => latLngToUnitSphere(center) * cameraDistance(zoom);

  /// Combined view*projection matrix for a [viewport] of the given size.
  Matrix4 viewProjection(Size viewport) {
    final aspect = viewport.width / viewport.height;
    final proj = makePerspectiveMatrix(
      45 * math.pi / 180, aspect, 0.01, 100,
    );
    // Up vector: world +Y, unless looking straight down a pole (then +Z).
    final eye = eyePosition();
    final up = (center.latitude.abs() > 89.0) ? Vector3(0, 0, 1) : Vector3(0, 1, 0);
    final view = makeViewMatrix(eye, Vector3.zero(), up);
    return proj * view;
  }

  GlobeCamera copyWith({LatLng? center, double? zoom, double? bearing, double? tilt}) =>
      GlobeCamera(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        bearing: bearing ?? this.bearing,
        tilt: tilt ?? this.tilt,
      );
}
```

Note: `makePerspectiveMatrix`, `makeViewMatrix` come from `package:vector_math/vector_math.dart` — add to the import: `show Vector3, Matrix4, makePerspectiveMatrix, makeViewMatrix`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/globe/globe_camera_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/globe/globe_camera.dart test/globe/globe_camera_test.dart
git commit -m "feat(globe): orbit camera (distance, eye, viewProjection)"
```

---

## Task 3: UV-sphere mesh

**Files:**
- Create: `lib/src/globe/sphere_mesh.dart`
- Test: `test/globe/sphere_mesh_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/globe/sphere_mesh_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/src/globe/sphere_mesh.dart';

void main() {
  test('mesh has (bands+1)*(segments+1) vertices', () {
    final m = SphereMesh.generate(bands: 4, segments: 6);
    expect(m.vertexCount, (4 + 1) * (6 + 1));
    // 5 floats per vertex: x,y,z,u,v
    expect(m.vertices.length, m.vertexCount * 5);
  });

  test('every vertex position lies on the unit sphere', () {
    final m = SphereMesh.generate(bands: 8, segments: 12);
    for (var i = 0; i < m.vertexCount; i++) {
      final x = m.vertices[i * 5 + 0];
      final y = m.vertices[i * 5 + 1];
      final z = m.vertices[i * 5 + 2];
      final r = (x * x + y * y + z * z);
      expect(r, closeTo(1.0, 1e-6));
    }
  });

  test('uv coordinates are within [0,1]', () {
    final m = SphereMesh.generate(bands: 4, segments: 4);
    for (var i = 0; i < m.vertexCount; i++) {
      final u = m.vertices[i * 5 + 3];
      final v = m.vertices[i * 5 + 4];
      expect(u, inInclusiveRange(0.0, 1.0));
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });

  test('index count is bands*segments*6 (two triangles per quad)', () {
    final m = SphereMesh.generate(bands: 4, segments: 6);
    expect(m.indices.length, 4 * 6 * 6);
    // all indices reference valid vertices
    expect(m.indices.every((i) => i < m.vertexCount), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/globe/sphere_mesh_test.dart`
Expected: FAIL — `sphere_mesh.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/globe/sphere_mesh.dart
import 'dart:math' as math;
import 'dart:typed_data';

/// A UV sphere as interleaved float32 vertices [x,y,z,u,v] + uint16 indices.
/// Positions lie on the unit sphere; UVs are equirectangular (u=lng, v=lat).
class SphereMesh {
  SphereMesh._(this.vertices, this.indices, this.vertexCount);

  final Float32List vertices;
  final Uint16List indices;
  final int vertexCount;

  static SphereMesh generate({int bands = 96, int segments = 192}) {
    final vertexCount = (bands + 1) * (segments + 1);
    final verts = Float32List(vertexCount * 5);
    final idx = Uint16List(bands * segments * 6);

    var vp = 0;
    for (var b = 0; b <= bands; b++) {
      final v = b / bands; // 0 at north pole .. 1 at south pole
      final lat = (0.5 - v) * math.pi; // +pi/2 .. -pi/2
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);
      for (var s = 0; s <= segments; s++) {
        final u = s / segments; // 0..1 around the globe
        final lng = (u - 0.5) * 2 * math.pi; // -pi..pi
        verts[vp++] = cosLat * math.cos(lng); // x
        verts[vp++] = sinLat; // y
        verts[vp++] = cosLat * math.sin(lng); // z
        verts[vp++] = u; // U
        verts[vp++] = v; // V
      }
    }

    var ip = 0;
    final stride = segments + 1;
    for (var b = 0; b < bands; b++) {
      for (var s = 0; s < segments; s++) {
        final i0 = b * stride + s;
        final i1 = i0 + 1;
        final i2 = i0 + stride;
        final i3 = i2 + 1;
        idx[ip++] = i0; idx[ip++] = i2; idx[ip++] = i1;
        idx[ip++] = i1; idx[ip++] = i2; idx[ip++] = i3;
      }
    }

    return SphereMesh._(verts, idx, vertexCount);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/globe/sphere_mesh_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/globe/sphere_mesh.dart test/globe/sphere_mesh_test.dart
git commit -m "feat(globe): UV-sphere mesh generation"
```

---

## Task 4: Shader bundle + pubspec (device-gated)

**Files:**
- Modify: `pubspec.yaml`
- Create: `shaders/globe.vert`, `shaders/globe.frag`, `shaders/globe.shaderbundle.json`

No unit test — shaders compile at build time and run on-device only.

- [ ] **Step 1: Add the flutter_gpu deps + shader bundle to `pubspec.yaml`**

Under `dependencies:` add:

```yaml
  flutter_gpu:
    sdk: flutter
  vector_math: ^2.1.4
```

Under `dev_dependencies:` add:

```yaml
  flutter_gpu_shaders: ^0.1.0
```

Under the `flutter:` section add the shader bundle build hook:

```yaml
  shader_bundles:
    - shaders/globe.shaderbundle.json
```

- [ ] **Step 2: Write `shaders/globe.shaderbundle.json`**

```json
{
  "GlobeVertex": {
    "type": "vertex",
    "file": "shaders/globe.vert"
  },
  "GlobeFragment": {
    "type": "fragment",
    "file": "shaders/globe.frag"
  }
}
```

- [ ] **Step 3: Write `shaders/globe.vert`**

```glsl
#version 460 core

uniform FrameInfo {
  mat4 mvp;
} frame_info;

in vec3 position;
in vec2 uv;

out vec2 v_uv;

void main() {
  gl_Position = frame_info.mvp * vec4(position, 1.0);
  v_uv = uv;
}
```

- [ ] **Step 4: Write `shaders/globe.frag`**

```glsl
#version 460 core

uniform sampler2D atlas;

in vec2 v_uv;
out vec4 frag_color;

void main() {
  frag_color = texture(atlas, v_uv);
}
```

- [ ] **Step 5: Verify the bundle compiles**

Run: `flutter pub get && flutter build bundle`
Expected: build succeeds and `flutter analyze` is clean. (Shader compilation runs via the `flutter_gpu_shaders` hook; if `flutter build bundle` does not trigger it on this SDK, the bundle compiles on first `flutter run` — confirmed in Task 7.)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml shaders/
git commit -m "feat(globe): flutter_gpu deps + globe shader bundle"
```

---

## Task 5: GlobeRenderer (device-gated)

**Files:**
- Create: `lib/src/globe/globe_renderer.dart`

No headless unit test — exercises `flutter_gpu`. Verified on device in Task 7.

- [ ] **Step 1: Write the renderer**

```dart
// lib/src/globe/globe_renderer.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' show Matrix4;

import 'sphere_mesh.dart';

/// Owns all flutter_gpu resources and draws the textured sphere to a texture.
/// All experimental GPU calls live here so API churn is contained to one file.
class GlobeRenderer {
  GlobeRenderer({SphereMesh? mesh})
      : _mesh = mesh ?? SphereMesh.generate();

  final SphereMesh _mesh;
  gpu.ShaderLibrary? _shaderLib;
  gpu.DeviceBuffer? _vertices;
  gpu.DeviceBuffer? _indices;
  gpu.Texture? _atlas;

  /// Load shaders + upload static geometry. Call once.
  void initialize() {
    _shaderLib = gpu.ShaderLibrary.fromAsset('shaders/globe.shaderbundle.json');
    _vertices = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(_mesh.vertices),
    );
    _indices = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(_mesh.indices),
    );
  }

  /// Replace the sphere texture (equirectangular atlas). Phase 0 passes a static
  /// decoded image's pixels; later phases pass the TileAtlas output.
  void setAtlasPixels(Uint8List rgba, int width, int height) {
    final tex = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible, width, height,
    );
    tex?.overwrite(ByteData.sublistView(rgba));
    _atlas = tex;
  }

  /// Render one frame into [target] using [mvp]. Returns when encoded.
  void render(gpu.Texture target, Matrix4 mvp) {
    final lib = _shaderLib;
    final vbo = _vertices;
    final ibo = _indices;
    final atlas = _atlas;
    if (lib == null || vbo == null || ibo == null || atlas == null) return;

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: target,
        clearValue: ui.Color(0x00000000),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final pipeline = gpu.gpuContext.createRenderPipeline(
      lib['GlobeVertex']!, lib['GlobeFragment']!,
    );
    pass.bindPipeline(pipeline);
    pass.setDepthWriteEnable(true);

    pass.bindVertexBuffer(
      gpu.BufferView(vbo, offsetInBytes: 0, lengthInBytes: _mesh.vertices.lengthInBytes),
      _mesh.vertexCount,
    );
    pass.bindIndexBuffer(
      gpu.BufferView(ibo, offsetInBytes: 0, lengthInBytes: _mesh.indices.lengthInBytes),
      gpu.IndexType.int16,
      _mesh.indices.length,
    );

    final transients = gpu.gpuContext.createHostBuffer();
    final mvpView = transients.emplace(ByteData.sublistView(mvp.storage));
    pass.bindUniform(lib['GlobeVertex']!.getUniformSlot('FrameInfo'), mvpView);
    pass.bindTexture(lib['GlobeFragment']!.getUniformSlot('atlas'), atlas);

    pass.draw();
    commandBuffer.submit();
  }

  void dispose() {
    _vertices = null;
    _indices = null;
    _atlas = null;
    _shaderLib = null;
  }
}
```

> **API note for the implementer:** `flutter_gpu` is experimental; exact method
> names (`overwrite`, `RenderTarget.singleColor`, `getUniformSlot`, `emplace`)
> match the SDK at `bin/cache/pkg/flutter_gpu/lib/src/`. If a symbol differs on
> the pinned SDK, consult that source directly and adjust — keep all such changes
> inside this file. Do not let GPU API drift leak into other files.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/src/globe/globe_renderer.dart`
Expected: No analyzer errors (runtime correctness is verified on device in Task 7).

- [ ] **Step 3: Commit**

```bash
git add lib/src/globe/globe_renderer.dart
git commit -m "feat(globe): GlobeRenderer (flutter_gpu textured-sphere draw)"
```

---

## Task 6: Minimal MapcnGlobe widget

**Files:**
- Create: `lib/src/globe/mapcn_globe.dart`
- Test: `test/globe/mapcn_globe_test.dart` (non-GPU behavior only)

- [ ] **Step 1: Write the failing widget test**

```dart
// test/globe/mapcn_globe_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:mapcn_flutter/src/globe/mapcn_globe.dart';

void main() {
  testWidgets('horizontal drag changes the camera longitude', (tester) async {
    LatLng? seen;
    await tester.pumpWidget(MaterialApp(
      home: MapcnGlobe(
        initialCenter: const LatLng(0, 0),
        onCameraChanged: (cam) => seen = cam.center,
        renderEnabled: false, // skip GPU in tests
      ),
    ));
    await tester.drag(find.byType(MapcnGlobe), const Offset(100, 0));
    await tester.pump();
    expect(seen, isNotNull);
    expect(seen!.longitude, isNot(0)); // dragging rotated the globe
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/globe/mapcn_globe_test.dart`
Expected: FAIL — `mapcn_globe.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/globe/mapcn_globe.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'globe_camera.dart';

/// Phase-0 minimal globe: drag-to-rotate orbit camera. The GPU draw is wired in
/// when [renderEnabled] is true (device only); tests run with it false.
class MapcnGlobe extends StatefulWidget {
  const MapcnGlobe({
    required this.initialCenter,
    this.initialZoom = 2,
    this.onCameraChanged,
    this.renderEnabled = true,
    super.key,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final void Function(GlobeCamera camera)? onCameraChanged;
  final bool renderEnabled;

  @override
  State<MapcnGlobe> createState() => _MapcnGlobeState();
}

class _MapcnGlobeState extends State<MapcnGlobe> {
  late GlobeCamera _camera;

  @override
  void initState() {
    super.initState();
    _camera = GlobeCamera(center: widget.initialCenter, zoom: widget.initialZoom);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // 1 logical pixel ~ 0.3 degrees; horizontal -> lng, vertical -> lat.
    final newLng = (_camera.center.longitude - d.delta.dx * 0.3);
    final wrapped = ((newLng + 180) % 360 + 360) % 360 - 180;
    final newLat = (_camera.center.latitude + d.delta.dy * 0.3).clamp(-89.0, 89.0);
    setState(() {
      _camera = _camera.copyWith(center: LatLng(newLat, wrapped));
    });
    widget.onCameraChanged?.call(_camera);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const SizedBox.expand(),
        // Phase 1+ replaces the Container child with the GPU Texture when
        // widget.renderEnabled is true.
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/globe/mapcn_globe_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/globe/mapcn_globe.dart test/globe/mapcn_globe_test.dart
git commit -m "feat(globe): minimal MapcnGlobe widget with drag-rotate camera"
```

---

## Task 7: Device spike — go/no-go gate

**Files:**
- Modify: `example/lib/main.dart` (add a temporary globe route) OR create `example/lib/globe_spike.dart`

This task is **manual** and is the entire point of Phase 0.

- [ ] **Step 1: Wire a spike screen**

Create `example/lib/globe_spike.dart` that loads a static equirectangular image
(e.g. a bundled world JPG, or one CARTO tile blitted full-frame) and renders it on
the sphere via `GlobeRenderer`, driving frames with a `Ticker` and the
`MapcnGlobe` camera. (Full wiring code is produced during implementation, against
the then-current `flutter_gpu` API.)

- [ ] **Step 2: Run on a device/simulator with Impeller**

Run: `cd example && flutter run` (iOS simulator or Android emulator with Impeller)
Verify:
- a textured sphere appears,
- dragging rotates it smoothly,
- no GPU validation errors in the console.

- [ ] **Step 3: Record the go/no-go decision**

If it renders and rotates: **GO** — proceed to Phase 1 (TileAtlas).
If `flutter_gpu` is unusable on the pinned SDK (missing symbols, no Impeller on
target devices): **NO-GO** — fall back to the design's Risks section (revisit
Mapbox or WebView paths) before investing in Phases 1–4.

- [ ] **Step 4: Commit the spike (kept as a reference example)**

```bash
git add example/lib/globe_spike.dart example/lib/main.dart
git commit -m "feat(globe): device spike screen (go/no-go gate)"
```

---

## Self-Review

**Spec coverage (Phase 0 scope):** `flutter_gpu` textured UV sphere + orbit camera
+ static image + drag-rotate, on device (spec Phase 0) — Tasks 1–7. Pure-Dart math
foundation unit-tested (spec "Testable seams") — Tasks 1–3. GPU quarantined in
`GlobeRenderer` (spec architecture) — Task 5.

**Placeholder scan:** Task 7 Step 1 intentionally defers exact wiring code to
implementation time because it depends on the live `flutter_gpu` API and a chosen
static image — this is a manual device task, not an automated one, so it carries
guidance rather than fictional "expected PASS" output. All automated tasks (1–3, 6)
have complete code + real expected results.

**Type consistency:** `GlobeCamera` (center/zoom/bearing/tilt/copyWith/eyePosition/
viewProjection), `latLngToUnitSphere`, `isFrontFacing`, `projectToScreen`,
`SphereMesh.generate(bands,segments)`/`vertices`/`indices`/`vertexCount`,
`GlobeRenderer.initialize/setAtlasPixels/render/dispose` are used consistently and
carry forward into Phases 1–4 unchanged.
