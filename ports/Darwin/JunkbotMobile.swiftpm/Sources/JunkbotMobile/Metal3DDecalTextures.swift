import CoreGraphics
import Metal

/// Junkbot's chest recycle emblem, as a small textured quad drawn in front of the body's own
/// LDraw geometry (the same technique `tools/Junkbot3D/Sources/Junkbot3D/DecalTextures.swift`
/// already uses for the trash bin's front sticker: "a flat plane rather than baked into a curved
/// cylinder's wraparound UVs"). The baked LDraw body brick itself carries no UV coordinates (only
/// position/normal/color - see `Metal3DModel.swift`), so a decal can't be textured onto its own
/// surface directly; a thin transparent-background quad sitting just in front of it reads the same
/// at this scale. Ported from that file's `drawRecycleLoop`/`front(bodyColor:)`, but drawn with
/// plain `CoreGraphics` (no `AppKit`/`NSImage`) directly into an RGBA8 buffer, matching
/// `Metal3DManager.loadTexture`'s manual-decode approach rather than going through `MTKTextureLoader`.
enum Metal3DDecalTextures {
  /// A transparent-background emblem: two broken arcs, each capped with a small arrowhead - the
  /// universal "chasing arrows" recycle glyph - in `strokeColor`.
  static func chestEmblem(strokeColor: SIMD4<Float>, device: MTLDevice) -> MTLTexture? {
    let size = 128
    let bytesPerRow = size * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    let color = CGColor(
      red: CGFloat(strokeColor.x), green: CGFloat(strokeColor.y), blue: CGFloat(strokeColor.z),
      alpha: CGFloat(strokeColor.w))
    context.setStrokeColor(color)
    context.setFillColor(color)
    context.setLineWidth(9)
    context.setLineCap(.round)

    let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    let radius: CGFloat = 34
    for half in 0..<2 {
      let start = CGFloat(half) * .pi + .pi / 10
      let end = start + .pi * 0.72
      context.addArc(
        center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
      context.strokePath()

      let tip = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
      let tangent = CGPoint(x: -sin(end), y: cos(end))
      let normal = CGPoint(x: cos(end), y: sin(end))
      let headLen: CGFloat = radius * 0.5
      let headWidth: CGFloat = radius * 0.4
      let base1 = CGPoint(
        x: tip.x - tangent.x * headLen + normal.x * headWidth * 0.5,
        y: tip.y - tangent.y * headLen + normal.y * headWidth * 0.5)
      let base2 = CGPoint(
        x: tip.x - tangent.x * headLen - normal.x * headWidth * 0.5,
        y: tip.y - tangent.y * headLen - normal.y * headWidth * 0.5)
      context.move(to: tip)
      context.addLine(to: base1)
      context.addLine(to: base2)
      context.closePath()
      context.fillPath()
    }

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
    texture.replace(
      region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: pixels,
      bytesPerRow: bytesPerRow)
    return texture
  }
}
