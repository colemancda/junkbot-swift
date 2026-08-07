import Foundation
#if canImport(simd)
import simd
#endif

/// One vertex in the combined per-frame buffer `Metal3DManager` uploads - layout must match
/// `Metal3DShaderSource`'s `VertexIn` struct exactly (`position`@0, `normal`@16, `color`@32,
/// matching `SIMD3<Float>`'s 16-byte alignment).
struct Metal3DVertex {
  var position: SIMD3<Float>
  var normal: SIMD3<Float>
  var color: SIMD4<Float>
}

/// Matches `Metal3DShaderSource`'s `Uniforms` struct exactly.
struct Metal3DUniforms {
  var modelViewProjection: float4x4
  var normalMatrix: float4x4
}

/// One rigid piece of a baked model - decoded counterpart of
/// `tools/Junkbot3D/Sources/Junkbot3D/Metal3DExporter.swift`'s `BakedSubmesh` (same JSON shape,
/// vertex data flattened to raw `Float` arrays rather than a custom binary layout).
struct Metal3DBakedSubmesh: Codable {
  var transform: [Float]  // float4x4, column-major, 16 floats
  var positions: [Float]  // 3 floats/vertex
  var normals: [Float]  // 3 floats/vertex
  var colors: [Float]  // 4 floats/vertex

  var vertexCount: Int { positions.count / 3 }

  var transformMatrix: float4x4 {
    float4x4(
      columns: (
        SIMD4<Float>(transform[0], transform[1], transform[2], transform[3]),
        SIMD4<Float>(transform[4], transform[5], transform[6], transform[7]),
        SIMD4<Float>(transform[8], transform[9], transform[10], transform[11]),
        SIMD4<Float>(transform[12], transform[13], transform[14], transform[15])
      ))
  }
}

struct Metal3DBakedModel: Codable {
  var submeshes: [Metal3DBakedSubmesh]
}

/// Loads (and caches, once per process) each entity type's baked-model JSON from the bundled
/// `Models3D` directory - the Metal counterpart of `Scene3DManager.loadedModel(named:)`, which
/// loads the same directory's `.scn` siblings instead.
@GameActor
enum Metal3DModelCache {
  private static var cache: [String: Metal3DBakedModel] = [:]

  static func model(named name: String) -> Metal3DBakedModel? {
    if let cached = cache[name] { return cached }
    guard
      let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Models3D")
        ?? Bundle.main.url(forResource: name, withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let model = try? JSONDecoder().decode(Metal3DBakedModel.self, from: data)
    else { return nil }
    cache[name] = model
    return model
  }
}
