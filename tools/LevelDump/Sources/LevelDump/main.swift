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
  FileHandle.standardError.write(Data("usage: LevelDump <repo_root> <output.swift>\n".utf8))
  exit(2)
}
let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
let outputPath = CommandLine.arguments[2]

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

/// Renders one `EmbeddedLevel(...)` literal by running `text` through the real parser + entity
/// bridge, once, on a scratch engine.
func embeddedLevelLiteral(title: String, text: String, game: Game, indent: String) -> String {
  let level = Level(text: text)
  let engine = GameEngine()
  engine.loadLevel(level)

  var builder = "{\n"
  builder += "\(indent)      var entities: [Entity] = []\n"
  builder += "\(indent)      entities.reserveCapacity(\(engine.entities.count))\n"
  for entity in engine.entities {
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

var output = """
  // Generated by `make codegen` (tools/LevelDump) - do not edit.
  //
  // Every campaign level (both games, each in their own `_LEVEL_LISTING.txt` order) plus the
  // title-screen decoration level, pre-parsed on the host through JunkbotCore's own text parser +
  // entity bridge and frozen as entity-builder code - see tools/LevelDump/Sources/LevelDump/
  // main.swift's header comment for why. Load with `GameEngine.loadLevel(_:EmbeddedLevel)`
  // (`Sources/JunkbotCore/EmbeddedLevel.swift`).

  public let embeddedLevels: [EmbeddedLevel] = [

  """

let catalog = LevelCatalog(repoRoot: repoRoot)
var entryLiterals: [String] = []
for game: Game in [.junkbot, .junkbotUndercover] {
  let entries = (catalog.pagesByGame[game] ?? []).flatMap { $0 }
  guard !entries.isEmpty else {
    FileHandle.standardError.write(Data("error: no levels found for \(game)\n".utf8))
    exit(1)
  }
  for entry in entries {
    guard let text = readLevelText(at: entry.url) else {
      FileHandle.standardError.write(Data("error: unreadable \(entry.url.path)\n".utf8))
      exit(1)
    }
    entryLiterals.append(
      embeddedLevelLiteral(title: entry.title, text: text, game: game, indent: "  ") + ",")
  }
}
output += entryLiterals.joined(separator: "\n")
output += "\n]\n\n"

// The title screen's decorative background level (levels/custom/Title Screen.txt) isn't part of
// either game's paginated catalog - every native port loads it directly by fixed path for its
// menu/title-screen background.
let titleScreenURL = repoRoot.appendingPathComponent("levels/custom/Title Screen.txt")
guard let titleScreenText = readLevelText(at: titleScreenURL) else {
  FileHandle.standardError.write(Data("error: unreadable \(titleScreenURL.path)\n".utf8))
  exit(1)
}
output += "public let titleScreenLevel: EmbeddedLevel = "
output += embeddedLevelLiteral(title: "Title Screen", text: titleScreenText, game: .junkbot, indent: "")
output += "\n"

try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
print("LevelDump: \(entryLiterals.count) levels + title screen -> \(outputPath)")
