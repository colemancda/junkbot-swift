// Build-time level converter, run via `make codegen` (see the root Makefile).
//
// Every port used to load level data by parsing `levels/*.txt` at runtime through
// `Sources/JunkbotCore`'s text parser (`LevelParse.swift`/`LevelEntityBridge.swift`). That parser
// needs full-Unicode `String` operations (`.lowercased()`, `Character` iteration) that don't fit
// Embedded Swift's data-table budget (see `Sources/JunkbotCore/Level.swift`'s note) - a real
// problem for `ports/NDS` and `ports/Web`, which is why this exists at all: this tool runs the
// *real* parser + entity bridge natively on the host, once, and freezes every level's resulting
// entity list, bounds, background, and metadata as plain Swift
// (`Sources/JunkbotCore/Generated/LevelData.swift`) - the same `EmbeddedLevel`/entity-builder
// approach `ports/NDS` originally used standalone (see git history), now shared by every port so
// none of them touch level *text* at runtime, only pre-parsed data.
//
// Usage: swift run --package-path tools/LevelDump LevelDump <repo_root> <output.swift>

import Foundation
import JunkbotCore

guard CommandLine.arguments.count == 3 else {
  FileHandle.standardError.write(Data("usage: LevelDump <repo_root> <output_directory>\n".utf8))
  exit(2)
}
let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func readLevelText(at url: URL) -> String? {
  guard var text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
  if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
  return text
}

func resolveDecals(_ levelDecals: [LevelDecal]) -> [DecalInstance] {
  var result: [DecalInstance] = []
  for decal in levelDecals {
    guard let spriteID = backgroundSpriteIDForName(decal.name) else { continue }
    result.append(DecalInstance(x: Int32(decal.x), y: Int32(decal.y), spriteID: spriteID))
  }
  return result
}

/// `e.<label> = <literal>` lines for every stored property of `entity` that differs from a
/// freshly-initialized entity with the same id/type/geometry. All `Entity` fields are `Int32`,
/// `Bool`, or `EntityType` (handled by the initializer).
func fieldAssignments(for entity: Entity) -> [String] {
  let defaults = Entity(
    id: entity.id, type: entity.type, x: entity.x, y: entity.y,
    width: entity.width, height: entity.height)
  let entityMirror = Mirror(reflecting: entity)
  let defaultsMirror = Mirror(reflecting: defaults)
  var lines: [String] = []
  for (child, defaultChild) in zip(entityMirror.children, defaultsMirror.children) {
    guard let label = child.label else { continue }
    switch (child.value, defaultChild.value) {
    case (let value as Int32, let defaultValue as Int32):
      if value != defaultValue { lines.append("e.\(label) = \(value)") }
    case (let value as Bool, let defaultValue as Bool):
      if value != defaultValue { lines.append("e.\(label) = \(value)") }
    case (is EntityType, is EntityType):
      break  // covered by the initializer
    default:
      FileHandle.standardError.write(
        Data("error: Entity.\(label) has an unsupported type for LevelDump\n".utf8))
      exit(1)
    }
  }
  return lines
}

func swiftStringLiteral(_ s: String) -> String {
  var out = "\""
  for c in s.unicodeScalars {
    switch c {
    case "\\": out += "\\\\"
    case "\"": out += "\\\""
    case "\n": out += "\\n"
    case "\r": out += "\\r"
    case "\t": out += "\\t"
    default:
      // A couple of hint strings contain stray control bytes that Swift source can't hold raw.
      if c.value < 0x20 || c.value == 0x7F {
        out += "\\u{\(String(c.value, radix: 16))}"
      } else {
        out.unicodeScalars.append(c)
      }
    }
  }
  return out + "\""
}

/// Widths (in studs) that actually have brick sprite art. Verified against the generated
/// `spriteDataOffsetTable` in every port's `build/SpriteAssets.swift`: `brickWhiteBase`/
/// `brickRedBase`/`brickYellowBase`/`brickImmobileBase` (the default/gray family used by plain
/// fixed terrain) are all missing widths 5 and 7 (gap slots, offset -1) - only `brickGreenBase`
/// happens to have full 1-8 coverage. A merge that lands on 5 or 7 studs for any of the gapped
/// colors silently fails to render (the sprite ID resolves to a gap slot), which is exactly the
/// "brick disappeared from the floor" bug this constant fixes - restricting to the widths valid
/// for every color, not just green, since `mergeAdjacentFixedBricks` doesn't know which port's
/// (possibly gapped) atlas it'll end up paired with.
let validMergedBrickWidths: Set<Int32> = [1, 2, 3, 4, 6, 8]

/// Merges runs of adjacent `fixed` bricks (touching x edges, same y/height/color/every-other-field)
/// into fewer, wider single entities, landing only on widths with real sprite art
/// (`validMergedBrickWidths` above - not simply "anything up to 8", which can produce an
/// unrenderable 5- or 7-stud brick). Busy levels build floors/walls out of many small brick
/// segments - level 1 ("New Employee Training") has runs of 14-21 bricks sharing one y - and every
/// per-tick simulation cost (the two full sorts, `rebuildAccelerationStructures`, and especially
/// `simulateGravity`'s support-chain search, whose y-bucketed candidate lists are only as small as
/// the busiest y-band) scales with total entity count, not just what's on screen. This is safe
/// specifically because it's restricted to `fixed` bricks: they're never grabbable, so merging
/// changes nothing about what the player can pick up, and the merged sprite is pixel-identical to
/// the originals (LEGO brick art repeats its stud pattern uniformly with no unique end-cap tiles -
/// verified by comparing `brick_white_2`/`brick_white_4`/`brick_white_8`'s source art).
func mergeAdjacentFixedBricks(_ entities: [Entity]) -> [Entity] {
  /// A merge-eligibility signature: every field except x/width/widthInStuds/id must match (id/x/
  /// width vary per brick by definition; widthInStuds is what merging changes). Reuses
  /// `fieldAssignments` (already written to enumerate every non-default stored property) rather
  /// than hand-listing `Entity`'s fields a second time.
  func mergeKey(_ e: Entity) -> String? {
    guard e.type == .brick, e.fixed else { return nil }
    let otherFields = fieldAssignments(for: e).filter { !$0.hasPrefix("e.widthInStuds") }
    return "\(e.y)|\(e.height)|\(otherFields.sorted().joined(separator: ","))"
  }

  // Group eligible bricks' original indices by merge key, preserving first-seen order per group.
  var order: [String] = []
  var groups: [String: [Int]] = [:]
  for (i, e) in entities.enumerated() {
    guard let key = mergeKey(e) else { continue }
    if groups[key] == nil {
      order.append(key)
      groups[key] = []
    }
    groups[key]!.append(i)
  }

  var replacement: [Int: Entity] = [:]  // first-of-run index -> merged entity
  var removed: Set<Int> = []
  for key in order {
    let indices = groups[key]!.sorted { entities[$0].x < entities[$1].x }
    var runStart = 0
    while runStart < indices.count {
      var runEnd = runStart
      var widthInStuds = entities[indices[runStart]].widthInStuds
      while runEnd + 1 < indices.count {
        let current = entities[indices[runEnd]]
        let next = entities[indices[runEnd + 1]]
        guard current.x + current.width == next.x,
          validMergedBrickWidths.contains(widthInStuds + next.widthInStuds)
        else { break }
        widthInStuds += next.widthInStuds
        runEnd += 1
      }
      if runEnd > runStart {
        var merged = entities[indices[runStart]]
        merged.widthInStuds = widthInStuds
        merged.width = widthInStuds * CELL_W
        replacement[indices[runStart]] = merged
        for i in (runStart + 1)...runEnd { removed.insert(indices[i]) }
      }
      runStart = runEnd + 1
    }
  }

  guard !replacement.isEmpty || !removed.isEmpty else { return entities }
  var result: [Entity] = []
  result.reserveCapacity(entities.count - removed.count)
  for (i, e) in entities.enumerated() {
    if removed.contains(i) { continue }
    result.append(replacement[i] ?? e)
  }
  return result
}

/// Renders one `EmbeddedLevel(...)` literal by running `text` through the real parser + entity
/// bridge, once, on a scratch engine.
func embeddedLevelLiteral(title: String, text: String, game: Game, indent: String) -> String {
  let level = Level(text: text)
  let engine = GameEngine()
  engine.loadLevel(level)
  let mergedEntities = mergeAdjacentFixedBricks(engine.entities)

  var builder = "{\n"
  builder += "\(indent)      var entities: [Entity] = []\n"
  builder += "\(indent)      entities.reserveCapacity(\(mergedEntities.count))\n"
  for entity in mergedEntities {
    builder += "\(indent)      do {\n"
    builder +=
      "\(indent)        var e = Entity(id: \(entity.id), type: EntityType(rawValue: \(entity.type.rawValue))!, "
      + "x: \(entity.x), y: \(entity.y), width: \(entity.width), height: \(entity.height))\n"
    let assignments = fieldAssignments(for: entity)
    if assignments.isEmpty {
      // Silence the unmutated-variable warning without a separate binding.
      builder += "\(indent)        e.grabbed = false\n"
    }
    for line in assignments {
      builder += "\(indent)        \(line)\n"
    }
    builder += "\(indent)        entities.append(e)\n"
    builder += "\(indent)      }\n"
  }
  builder += "\(indent)      return entities\n"
  builder += "\(indent)    }"

  let boundsLiteral: String
  if let bounds = engine.levelBounds {
    boundsLiteral =
      "LevelBounds(x: \(bounds.x), y: \(bounds.y), width: \(bounds.width), height: \(bounds.height))"
  } else {
    boundsLiteral = "nil"
  }
  let parLiteral = engine.levelPar == Int.max ? "Int32.max" : "\(engine.levelPar)"
  let backdropID = backgroundSpriteIDForName(level.background?.backdrop ?? "bkg1") ?? -1
  let backgroundDecals = resolveDecals(level.background?.backgroundDecals ?? [])
  let decals = resolveDecals(level.background?.decals ?? [])
  func decalArrayLiteral(_ instances: [DecalInstance]) -> String {
    "[" + instances.map { "DecalInstance(x: \($0.x), y: \($0.y), spriteID: \($0.spriteID))" }
      .joined(separator: ", ") + "]"
  }
  let gameLiteral = game == .junkbot ? "Game.junkbot" : "Game.junkbotUndercover"

  return """
    \(indent)EmbeddedLevel(
    \(indent)  title: \(swiftStringLiteral(title)),
    \(indent)  hint: \(swiftStringLiteral(engine.levelHint)),
    \(indent)  par: \(parLiteral),
    \(indent)  bounds: \(boundsLiteral),
    \(indent)  backdropSpriteID: \(backdropID),
    \(indent)  backgroundDecals: \(decalArrayLiteral(backgroundDecals)),
    \(indent)  decals: \(decalArrayLiteral(decals)),
    \(indent)  game: \(gameLiteral),
    \(indent)  makeEntities: \(builder))
    """
}

// Each game's levels are emitted into their OWN file (not just their own array in one shared
// file): a size-constrained port that only ships one campaign (ports/NDS ships Junkbot only, not
// Undercover Exclusive) can exclude the other file entirely at the source level, the same way it
// already excludes Font.swift/LevelCatalog.swift - the constituent `EmbeddedLevel`s' entity-
// builder closures aren't excludable piecemeal from within a single compiled array literal once
// anything references it, even if only some elements are ever actually used at runtime.
let catalog = LevelCatalog(repoRoot: repoRoot)
var campaignArrayNames: [Game: String] = [:]
for game: Game in [.junkbot, .junkbotUndercover] {
  let entries = (catalog.pagesByGame[game] ?? []).flatMap { $0 }
  guard !entries.isEmpty else {
    FileHandle.standardError.write(Data("error: no levels found for \(game)\n".utf8))
    exit(1)
  }
  let arrayName = game == .junkbot ? "junkbotCampaignLevels" : "undercoverCampaignLevels"
  let fileName = game == .junkbot ? "JunkbotLevelData.swift" : "UndercoverLevelData.swift"
  campaignArrayNames[game] = arrayName

  var entryLiterals: [String] = []
  for entry in entries {
    guard let text = readLevelText(at: entry.url) else {
      FileHandle.standardError.write(Data("error: unreadable \(entry.url.path)\n".utf8))
      exit(1)
    }
    entryLiterals.append(
      embeddedLevelLiteral(title: entry.title, text: text, game: game, indent: "  ") + ",")
  }

  var fileOutput = """
    // Generated by `make codegen` (tools/LevelDump) - do not edit.
    //
    // One campaign's levels, in `_LEVEL_LISTING.txt` order, pre-parsed on the host through
    // JunkbotCore's own text parser + entity bridge and frozen as entity-builder code - see
    // tools/LevelDump/Sources/LevelDump/main.swift's header comment for why. Load with
    // `GameEngine.loadLevel(_:EmbeddedLevel)` (`Sources/JunkbotCore/EmbeddedLevel.swift`).

    public let \(arrayName): [EmbeddedLevel] = [

    """
  fileOutput += entryLiterals.joined(separator: "\n")
  fileOutput += "\n]\n"
  try fileOutput.write(
    to: outputDirectory.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
  print("LevelDump: \(entryLiterals.count) levels -> \(fileName)")
}

// The title screen's decorative background level (levels/custom/Title Screen.txt) isn't part of
// either game's paginated catalog - every native port loads it directly by fixed path for its
// menu/title-screen background.
let titleScreenURL = repoRoot.appendingPathComponent("levels/custom/Title Screen.txt")
guard let titleScreenText = readLevelText(at: titleScreenURL) else {
  FileHandle.standardError.write(Data("error: unreadable \(titleScreenURL.path)\n".utf8))
  exit(1)
}

// The combined view (both campaigns concatenated) - used by `EmbeddedLevelCatalog` and any port
// that doesn't need to exclude one campaign for size. Kept in its own tiny file so a port that
// DOES need to exclude a campaign (ports/NDS) can also exclude this one, avoiding a reference to
// the excluded campaign's array.
var combinedOutput = """
  // Generated by `make codegen` (tools/LevelDump) - do not edit.
  //
  // Every campaign's levels concatenated, plus the title-screen decoration level - see
  // JunkbotLevelData.swift/UndercoverLevelData.swift for the per-campaign arrays this combines,
  // and tools/LevelDump/Sources/LevelDump/main.swift's header comment for why any of this is
  // pre-parsed at build time rather than read as text on-device.

  public let embeddedLevels: [EmbeddedLevel] = \(campaignArrayNames[.junkbot]!) + \(campaignArrayNames[.junkbotUndercover]!)

  """
combinedOutput += "public let titleScreenLevel: EmbeddedLevel = "
combinedOutput += embeddedLevelLiteral(
  title: "Title Screen", text: titleScreenText, game: .junkbot, indent: "")
combinedOutput += "\n"
try combinedOutput.write(
  to: outputDirectory.appendingPathComponent("LevelData.swift"), atomically: true,
  encoding: .utf8)
print("LevelDump: combined embeddedLevels + titleScreenLevel -> LevelData.swift")
