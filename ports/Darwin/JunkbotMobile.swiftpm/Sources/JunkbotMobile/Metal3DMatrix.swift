import Foundation
#if canImport(simd)
import simd
#endif

/// Small `float4x4` builders shared by `Metal3DManager`/`Metal3DBrickGeometry` - kept local rather
/// than pulled from `swift-lego-draw` (whose equivalents are either `private` or perspective-only,
/// see `Metal3DShaderSource.swift`'s doc comment for why this Metal path doesn't depend on that
/// package at runtime at all).
enum Metal3DMatrix {
  static func translation(_ t: SIMD3<Float>) -> float4x4 {
    float4x4(
      columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(t.x, t.y, t.z, 1)
      ))
  }

  static func rotationX(_ angle: Float) -> float4x4 {
    // `cos`/`sin` only have a `Double` overload via Glibc on Linux/Android (unlike Darwin's
    // Foundation, which also exposes `Float` ones) - compute in `Double`, convert once, portable
    // to both without changing Darwin's result (same underlying libm call either way).
    let c = Float(cos(Double(angle))), s = Float(sin(Double(angle)))
    return float4x4(
      columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, c, s, 0),
        SIMD4<Float>(0, -s, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
      ))
  }

  static func rotationY(_ angle: Float) -> float4x4 {
    let c = Float(cos(Double(angle))), s = Float(sin(Double(angle)))
    return float4x4(
      columns: (
        SIMD4<Float>(c, 0, -s, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(s, 0, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
      ))
  }

  /// Right-handed look-at, matching SceneKit's `SCNNode.look(at:)` semantics closely enough for an
  /// orthographic camera that never rolls.
  static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let f = simd_normalize(center - eye)
    let r = simd_normalize(simd_cross(f, up))
    let u = simd_cross(r, f)
    return float4x4(
      columns: (
        SIMD4<Float>(r.x, u.x, -f.x, 0),
        SIMD4<Float>(r.y, u.y, -f.y, 0),
        SIMD4<Float>(r.z, u.z, -f.z, 0),
        SIMD4<Float>(-simd_dot(r, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
      ))
  }

  /// Metal's clip-space convention (z in `[0, 1]`, not OpenGL's `[-1, 1]`).
  static func orthographic(halfHeight: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let halfWidth = halfHeight * aspect
    let r = halfWidth, l = -halfWidth, t = halfHeight, b = -halfHeight
    return float4x4(
      columns: (
        SIMD4<Float>(2 / (r - l), 0, 0, 0),
        SIMD4<Float>(0, 2 / (t - b), 0, 0),
        SIMD4<Float>(0, 0, -1 / (far - near), 0),
        SIMD4<Float>(-(r + l) / (r - l), -(t + b) / (t - b), -near / (far - near), 1)
      ))
  }
}
