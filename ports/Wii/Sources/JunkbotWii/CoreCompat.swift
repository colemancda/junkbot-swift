// Two small pieces `GameEngine.swift` needs that normally live in `Level.swift`/`RenderList.swift`
// - neither of which this target compiles in (see ../Makefile's CORE_SOURCES comment): both files
// otherwise pull in `String` operations (`.lowercased()` et al) that need Unicode
// normalization/case-mapping tables which fail to link for `powerpc-none-none-eabi`. `DecalInstance`
// and `initLevelBounds` themselves have no String dependency, so they're reproduced here verbatim
// rather than pulling in everything else those two files bring with them.

/// One decal placement (backdrop/foreground decoration) - verbatim copy of `RenderList.swift`'s
/// definition; `GameEngine.backgroundDecals`/`decals` are typed against it directly.
public struct DecalInstance {
  public var x: Int32
  public var y: Int32
  public var spriteID: Int32

  public init(x: Int32, y: Int32, spriteID: Int32) {
    self.x = x
    self.y = y
    self.spriteID = spriteID
  }
}

extension GameEngine {
  /// Sets `levelBounds` to the given rectangle and centers the viewport on it - verbatim copy of
  /// `Level.swift`'s definition, called by `GameEngine.beginLoadLevel`.
  func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
    levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
    viewportCenterX = x + width / 2
    viewportCenterY = y + height / 2
  }
}
