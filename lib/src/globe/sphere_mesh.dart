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
        idx[ip++] = i0;
        idx[ip++] = i2;
        idx[ip++] = i1;
        idx[ip++] = i1;
        idx[ip++] = i2;
        idx[ip++] = i3;
      }
    }

    return SphereMesh._(verts, idx, vertexCount);
  }
}
