// Apple's `simd` module (the `float4x4` matrix type and `simd_normalize`/`simd_cross`/`simd_dot`/
// `simd_min`/`simd_max` free functions the reused `Metal3D*.swift`/`Vulkan3DManager*.swift` files
// depend on) doesn't exist on Linux/Android - only `SIMD2`/`SIMD3`/`SIMD4` themselves are portable
// (part of the Swift standard library itself, not the `simd` module). This provides a minimal,
// source-compatible `float4x4` plus the handful of free functions those files actually call, so
// the exact same source compiles unmodified on both platforms - see each of those files' own doc
// comments for which pieces this covers.
#if !canImport(simd)

public struct float4x4: Sendable {
  public var columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)

  public init(columns: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)) {
    self.columns = columns
  }

  public init(diagonal: SIMD4<Float>) {
    columns = (
      SIMD4<Float>(diagonal.x, 0, 0, 0),
      SIMD4<Float>(0, diagonal.y, 0, 0),
      SIMD4<Float>(0, 0, diagonal.z, 0),
      SIMD4<Float>(0, 0, 0, diagonal.w)
    )
  }
}

public let matrix_identity_float4x4 = float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))

/// Column-major matrix multiply, matching Apple `simd`'s own `float4x4 * float4x4` semantics.
public func * (lhs: float4x4, rhs: float4x4) -> float4x4 {
  func column(_ c: SIMD4<Float>) -> SIMD4<Float> {
    lhs.columns.0 * c.x + lhs.columns.1 * c.y + lhs.columns.2 * c.z + lhs.columns.3 * c.w
  }
  return float4x4(columns: (column(rhs.columns.0), column(rhs.columns.1), column(rhs.columns.2), column(rhs.columns.3)))
}

public func * (lhs: float4x4, rhs: SIMD4<Float>) -> SIMD4<Float> {
  lhs.columns.0 * rhs.x + lhs.columns.1 * rhs.y + lhs.columns.2 * rhs.z + lhs.columns.3 * rhs.w
}

public func simd_dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
  a.x * b.x + a.y * b.y + a.z * b.z
}

public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
  SIMD3<Float>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

public func simd_normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
  let length = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
  return length > 0 ? v / length : v
}

public func simd_min(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
  SIMD3<Float>(Swift.min(a.x, b.x), Swift.min(a.y, b.y), Swift.min(a.z, b.z))
}

public func simd_max(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
  SIMD3<Float>(Swift.max(a.x, b.x), Swift.max(a.y, b.y), Swift.max(a.z, b.z))
}

#endif
