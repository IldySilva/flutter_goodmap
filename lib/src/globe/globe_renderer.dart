import 'dart:typed_data';

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' show Matrix4, Vector4;

import 'sphere_mesh.dart';

/// Owns all `flutter_gpu` resources and draws the textured sphere into a target
/// texture. Every experimental GPU call lives here so API churn is contained to
/// one file (per the design's risk mitigation).
///
/// Verified on device (Impeller) — not exercised by headless `flutter test`.
class GlobeRenderer {
  GlobeRenderer({SphereMesh? mesh}) : _mesh = mesh ?? SphereMesh.generate();

  final SphereMesh _mesh;
  gpu.ShaderLibrary? _shaderLib;
  gpu.DeviceBuffer? _vertices;
  gpu.DeviceBuffer? _indices;
  gpu.Texture? _atlas;

  /// Load shaders + upload the static sphere geometry. Call once.
  void initialize() {
    _shaderLib = gpu.ShaderLibrary.fromAsset('shaders/globe.shaderbundle.json');
    _vertices = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(_mesh.vertices),
    );
    _indices = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(_mesh.indices),
    );
  }

  /// Replace the equirectangular sphere texture. Phase 0 passes a decoded static
  /// image's RGBA bytes; later phases pass the `TileAtlas` output.
  void setAtlasPixels(Uint8List rgba, int width, int height) {
    final tex = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      width,
      height,
    );
    tex.overwrite(ByteData.sublistView(rgba));
    _atlas = tex;
  }

  /// Render one frame of the sphere into [target] using [mvp].
  void render(gpu.Texture target, Matrix4 mvp) {
    final lib = _shaderLib;
    final vbo = _vertices;
    final ibo = _indices;
    final atlas = _atlas;
    if (lib == null || vbo == null || ibo == null || atlas == null) return;

    final vertex = lib['GlobeVertex']!;
    final fragment = lib['GlobeFragment']!;

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: target,
        clearValue: Vector4.zero(),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    pass.bindPipeline(pipeline);
    // Convex sphere: cull back faces so the far hemisphere doesn't overdraw.
    pass.setCullMode(gpu.CullMode.backFace);

    pass.bindVertexBuffer(
      gpu.BufferView(vbo,
          offsetInBytes: 0, lengthInBytes: _mesh.vertices.lengthInBytes),
      _mesh.vertexCount,
    );
    pass.bindIndexBuffer(
      gpu.BufferView(ibo,
          offsetInBytes: 0, lengthInBytes: _mesh.indices.lengthInBytes),
      gpu.IndexType.int16,
      _mesh.indices.length,
    );

    final transients = gpu.gpuContext.createHostBuffer();
    final mvpView = transients.emplace(ByteData.sublistView(mvp.storage));
    pass.bindUniform(vertex.getUniformSlot('FrameInfo'), mvpView);
    pass.bindTexture(fragment.getUniformSlot('atlas'), atlas);

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
