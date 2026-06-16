import 'package:flutter_test/flutter_test.dart';
import 'package:mapcn_flutter/src/globe/sphere_mesh.dart';

void main() {
  test('mesh has (bands+1)*(segments+1) vertices, 5 floats each', () {
    final m = SphereMesh.generate(bands: 4, segments: 6);
    expect(m.vertexCount, (4 + 1) * (6 + 1));
    expect(m.vertices.length, m.vertexCount * 5);
  });

  test('every vertex position lies on the unit sphere', () {
    final m = SphereMesh.generate(bands: 8, segments: 12);
    for (var i = 0; i < m.vertexCount; i++) {
      final x = m.vertices[i * 5 + 0];
      final y = m.vertices[i * 5 + 1];
      final z = m.vertices[i * 5 + 2];
      expect(x * x + y * y + z * z, closeTo(1.0, 1e-6));
    }
  });

  test('uv coordinates are within [0,1]', () {
    final m = SphereMesh.generate(bands: 4, segments: 4);
    for (var i = 0; i < m.vertexCount; i++) {
      expect(m.vertices[i * 5 + 3], inInclusiveRange(0.0, 1.0));
      expect(m.vertices[i * 5 + 4], inInclusiveRange(0.0, 1.0));
    }
  });

  test('index count is bands*segments*6 and references valid vertices', () {
    final m = SphereMesh.generate(bands: 4, segments: 6);
    expect(m.indices.length, 4 * 6 * 6);
    expect(m.indices.every((i) => i < m.vertexCount), isTrue);
  });
}
