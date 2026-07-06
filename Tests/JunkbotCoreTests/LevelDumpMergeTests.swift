import Testing

@testable import JunkbotCore

/// Regression coverage for a real bug in `tools/LevelDump`'s `mergeAdjacentFixedBricks` (which
/// merges adjacent `fixed` bricks in the generated level data - see that function's doc comment):
/// it capped merged widths at <=8 studs, but the white/red/yellow/gray brick sprite families have
/// no art for 5 or 7 studs specifically (only green happens to have full 1-8 coverage - verified
/// against every port's generated `spriteDataOffsetTable`). A merge landing on one of those widths
/// produced a geometrically-valid entity that silently failed to render - a brick vanished from
/// the floor even though `GameEngine.entities` was entirely correct, only caught by eye in melonDS
/// (`ports/NDS`), not by the 43-level outcome suite (`LevelTests.swift`), since nothing there
/// checks *appearance*, only win/lose outcome.
///
/// `tools/LevelDump` is a separate SwiftPM package (an executable target, not directly importable
/// here), so this can't call `mergeAdjacentFixedBricks` itself - instead it checks its actual
/// output (the generated `Sources/JunkbotCore/Generated/*.swift` files this repo commits) against
/// the same constraint that function must uphold, for every level in both campaigns.
@Suite("Generated level data: brick widths are all renderable")
struct LevelDumpMergeTests {
  /// Widths (studs) missing sprite art for every color except green - see
  /// `tools/LevelDump/Sources/LevelDump/main.swift`'s `validMergedBrickWidths` doc comment for how
  /// this was derived (`spriteDataOffsetTable[base + width] == -1` for white/red/yellow/gray at
  /// widths 5 and 7, in every port's generated `build/SpriteAssets.swift`).
  static let unrenderableWidthsExceptGreen: Set<Int32> = [5, 7]
  /// `RenderList.swift`'s `entitySprite` maps `colorIndex` to a sprite base; green (2) is the only
  /// family with full 1-8 coverage.
  static let greenColorIndex: Int32 = 2

  func checkAllBrickWidthsRenderable(_ levels: [EmbeddedLevel], campaignName: String) {
    for level in levels {
      for entity in level.makeEntities() where entity.type == .brick {
        guard entity.colorIndex != Self.greenColorIndex else { continue }
        #expect(
          !Self.unrenderableWidthsExceptGreen.contains(entity.widthInStuds),
          "\(campaignName) level \"\(level.title)\" has a color-\(entity.colorIndex) brick at (\(entity.x),\(entity.y)) with widthInStuds=\(entity.widthInStuds), which has no sprite art for this color and will silently fail to render"
        )
      }
    }
  }

  @Test("Junkbot campaign: no brick has an unrenderable merged width")
  func junkbotCampaignBrickWidths() {
    checkAllBrickWidthsRenderable(junkbotCampaignLevels, campaignName: "Junkbot")
  }

  @Test("Undercover Exclusive campaign: no brick has an unrenderable merged width")
  func undercoverCampaignBrickWidths() {
    checkAllBrickWidthsRenderable(undercoverCampaignLevels, campaignName: "Undercover Exclusive")
  }
}
