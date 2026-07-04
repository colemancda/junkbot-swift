/// One platform-independent drawing operation, emitted by `RenderList.swift` and executed by a
/// backend that only blits: the JS/HTML5-canvas frontend (via the JunkbotWASM bridge) or the
/// native SDL3 target. Coordinates are world-space; each backend applies its own camera
/// transform. Sprites are identified by Int32 ID into the generated tables
/// (`Generated/SpriteTable.swift`) — never by name — so emission involves no String operations
/// or Dictionary lookups (embedded-WASM requirement).
public struct RenderCommand {
  public enum Kind: Int32 {
    case sprite = 0
    case solidRect = 1
  }

  public var kind: Kind
  /// `sprite`: global sprite ID (index into `spriteNameTable` etc.). `solidRect`: unused (0).
  public var spriteID: Int32
  /// World-space top-left of the blit/rect.
  public var x: Int32
  public var y: Int32
  /// `sprite`: opacity 0...100 (100 = opaque; the scale keeps JS's exact 0.8/0.3/0.5 values
  /// representable). `solidRect`: rect width.
  public var a: Int32
  /// `sprite`: rotation in milliradians around the destination-rect center (scaredy-bin wobble;
  /// normally 0). `solidRect`: rect height.
  public var b: Int32
  /// `sprite`: source/destination clip width in pixels, `0` = draw full frame (used by the laser
  /// beam's final-segment "depth illusion" trim). `solidRect`: fill color as 0xRRGGBBAA.
  public var c: Int32

  public static func sprite(
    _ spriteID: Int32, x: Int32, y: Int32, alpha: Int32 = 100, rotationMrad: Int32 = 0,
    clipWidth: Int32 = 0
  ) -> RenderCommand {
    RenderCommand(kind: .sprite, spriteID: spriteID, x: x, y: y, a: alpha, b: rotationMrad, c: clipWidth)
  }

  public static func solidRect(
    x: Int32, y: Int32, width: Int32, height: Int32, rgba: Int32
  ) -> RenderCommand {
    RenderCommand(kind: .solidRect, spriteID: 0, x: x, y: y, a: width, b: height, c: rgba)
  }
}

/// A complete world frame: the ordered command list plus the metadata backends need to
/// interleave their own overlays and to color a drag correctly.
public struct RenderFrame {
  public var commands: [RenderCommand] = []
  /// `commands[0..<backgroundCount]` is the backdrop+decals pass; the JS backend draws its
  /// in-world overlays that belong *between* background and entities (title-screen panel text,
  /// playback ghost) at this boundary.
  public var backgroundCount: Int = 0
  /// `canRelease()` at emission time — whether the current drag (if any) could commit here.
  /// Drives the grabbed-entity alpha (80 vs 30) and is reused by the JS host, which previously
  /// recomputed `canRelease()` itself every animation frame.
  public var placeable: Bool = false

  public init() {}
}
