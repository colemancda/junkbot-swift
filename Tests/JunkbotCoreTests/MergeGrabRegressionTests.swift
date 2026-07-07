import Foundation
import Testing

@testable import JunkbotCore

/// Compares play-mode grab behavior between the raw, unmerged `levels/*.txt` source and the
/// build-time-merged `Generated/*LevelData.swift` embedded catalog (produced by
/// `mergeAdjacentFixedBricks` in `tools/LevelDump`), to check whether merging adjacent `fixed`
/// bricks together changed what a player can grab. Since merging is restricted to `fixed`
/// entities (never independently grabbable), and `findAttachedGroup`/`possibleGrabsAt` key off
/// grabbable entities' own ids (never reassigned by the merge), any divergence here would be a
/// real regression in the grabbing algorithm caused by the merge. This also happens to be a good
/// end-to-end exerciser of `GameEngine.loadLevel(_:Level)` (see its `rebuildAccelerationStructures`
/// call): without that call, `entitiesByTopY`/`entitiesByBottomY` stay empty after a text-based
/// load, and `connectsToFixed`'s candidate lookup silently finds nothing, which this test would
/// misreport as a merge-caused grab difference.
@Suite("Merged-catalog grab parity")
struct MergeGrabRegressionTests {

  static var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  struct GrabSignature: Equatable {
    var canGrabDownward: Bool
    var canGrabUpward: Bool
    var downwardIDs: Set<Int32>
    var upwardIDs: Set<Int32>
  }

  static func grabSignatures(_ engine: GameEngine) -> [Int32: GrabSignature] {
    var result: [Int32: GrabSignature] = [:]
    for i in 0..<engine.entities.count {
      let e = engine.entities[i]
      guard !e.fixed, e.type == .brick || e.type == .jump || e.type == .shield else { continue }
      let grabs = engine.possibleGrabsInDirections(startIndex: i)
      result[e.id] = GrabSignature(
        canGrabDownward: grabs.canGrabDownward,
        canGrabUpward: grabs.canGrabUpward,
        downwardIDs: Set(grabs.grabDownward.map { engine.entities[$0].id }),
        upwardIDs: Set(grabs.grabUpward.map { engine.entities[$0].id })
      )
    }
    return result
  }

  @Test("Every Junkbot + Undercover campaign level: grab groups match between unmerged text and merged embedded data")
  func grabParityAcrossCampaigns() {
    let allEmbedded = junkbotCampaignLevels + undercoverCampaignLevels
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    var mismatches: [String] = []
    var checked = 0

    for (_, pages) in catalog.pagesByGame {
      for page in pages {
        for entry in page {
          guard
            let text = try? String(contentsOf: entry.url, encoding: .utf8)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
          else { continue }
          let textLevel = Level(text: text)
          guard
            let embedded = allEmbedded.first(where: {
              $0.title.description.lowercased() == textLevel.title.lowercased()
            })
          else { continue }

          let unmergedEngine = GameEngine()
          unmergedEngine.loadLevel(textLevel)
          let mergedEngine = GameEngine()
          mergedEngine.loadLevel(embedded)

          checked += 1
          let unmergedSigs = Self.grabSignatures(unmergedEngine)
          let mergedSigs = Self.grabSignatures(mergedEngine)

          guard Set(unmergedSigs.keys) == Set(mergedSigs.keys) else {
            mismatches.append(
              "\(textLevel.title): grabbable entity id sets differ (unmerged \(unmergedSigs.count), merged \(mergedSigs.count))"
            )
            continue
          }
          for (id, unmergedSig) in unmergedSigs {
            guard let mergedSig = mergedSigs[id], mergedSig == unmergedSig else {
              mismatches.append(
                "\(textLevel.title): entity id \(id) grab signature differs — unmerged \(unmergedSigs[id]!) vs merged \(mergedSigs[id] ?? unmergedSig)"
              )
              continue
            }
          }
        }
      }
    }

    #expect(checked > 50, "Expected to check most of the ~121 campaign levels, only checked \(checked)")
    #expect(mismatches.isEmpty, "Grab parity mismatches:\n\(mismatches.joined(separator: "\n"))")
  }

  @Test("Title Screen: grab groups match between unmerged text and merged embedded data")
  func titleScreenGrabParity() throws {
    let url = Self.repoRoot.appendingPathComponent(
      "ports/Darwin/JunkbotMobile.swiftpm/Sources/JunkbotMobile/levels/custom/Title Screen.txt")
    let text = try String(contentsOf: url, encoding: .utf8)
    let textLevel = Level(text: text)

    let unmergedEngine = GameEngine()
    unmergedEngine.loadLevel(textLevel)
    let mergedEngine = GameEngine()
    mergedEngine.loadLevel(titleScreenLevel)

    let unmergedSigs = Self.grabSignatures(unmergedEngine)
    let mergedSigs = Self.grabSignatures(mergedEngine)

    var mismatches: [String] = []
    guard Set(unmergedSigs.keys) == Set(mergedSigs.keys) else {
      Issue.record(
        "Title Screen: grabbable entity id sets differ (unmerged \(unmergedSigs.count), merged \(mergedSigs.count))"
      )
      return
    }
    for (id, unmergedSig) in unmergedSigs {
      guard let mergedSig = mergedSigs[id], mergedSig == unmergedSig else {
        mismatches.append(
          "Title Screen: entity id \(id) grab signature differs — unmerged \(unmergedSig) vs merged \(mergedSigs[id] as Any)"
        )
        continue
      }
    }
    #expect(mismatches.isEmpty, "Grab parity mismatches:\n\(mismatches.joined(separator: "\n"))")
  }

  @Test("DIAGNOSTIC: dump Title Screen movable bricks and their grab groups")
  func diagnosticTitleScreen() {
    let engine = GameEngine()
    engine.loadLevel(titleScreenLevel)
    for e in engine.entities where !e.fixed && (e.type == .brick || e.type == .jump || e.type == .shield) {
      print("movable id=\(e.id) x=\(e.x) y=\(e.y) w=\(e.width) h=\(e.height) color=\(e.colorIndex)")
    }
    for i in 0..<engine.entities.count {
      let e = engine.entities[i]
      guard !e.fixed, e.type == .brick || e.type == .jump || e.type == .shield else { continue }
      let grabs = engine.possibleGrabsInDirections(startIndex: i)
      print(
        "id=\(e.id) x=\(e.x) y=\(e.y): downward=\(grabs.canGrabDownward) \(grabs.grabDownward.map { engine.entities[$0].id }) upward=\(grabs.canGrabUpward) \(grabs.grabUpward.map { engine.entities[$0].id })"
      )
    }
  }
}
