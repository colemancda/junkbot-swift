import Foundation
import LDrawSceneKit
import LegoDrawFile
import SceneKit

/// Resolves subfile references by searching the standard LDraw library layout on disk - copied
/// from swift-lego-draw's own `Examples/RenderLDrawModel/FileSystemPartResolver.swift` (an
/// example executable target, not part of the library's public API, so not importable directly).
struct FileSystemPartResolver: LDrawPartResolver {
  var searchDirectories: [URL]

  func resolve(reference: String) throws(LDrawResolutionError) -> LDrawSourceFile? {
    let normalizedReference = reference.replacingOccurrences(of: "\\", with: "/")
    for directory in searchDirectories {
      for candidateName in [normalizedReference, normalizedReference.lowercased()] {
        let candidateURL = directory.appendingPathComponent(candidateName)
        guard FileManager.default.fileExists(atPath: candidateURL.path) else { continue }
        let text: String
        do {
          text = try String(contentsOf: candidateURL, encoding: .utf8)
        } catch {
          throw LDrawResolutionError.underlying("\(error)")
        }
        do {
          return try LDrawParser.parseFile(text)
        } catch {
          throw LDrawResolutionError.parseErrorInResolvedPart(reference: reference, error: error)
        }
      }
    }
    return nil
  }
}

/// Thin glue between this tool and `swift-lego-draw` (a real LDraw parser + BFC-aware SceneKit
/// builder - replacing this tool's original hand-rolled `LDrawLoader`, which ignored winding/
/// culling and skipped edge-line geometry entirely).
@MainActor
enum LDrawSupport {
  private static var cachedColorTable: LDrawColorTable?

  /// `LDConfig.ldr`'s color palette, parsed once per process.
  static func colorTable(ldrawRoot: URL) -> LDrawColorTable {
    if let cached = cachedColorTable { return cached }
    var table = LDrawColorTable()
    if let text = try? String(
      contentsOf: ldrawRoot.appendingPathComponent("LDConfig.ldr"), encoding: .utf8)
    {
      table = (try? LDrawColorTable.parsing(ldConfigText: text)) ?? table
    }
    cachedColorTable = table
    return table
  }

  /// Parses, resolves, and builds `text` (a single official part `.dat`, or one of our own
  /// authored `.ldr` models under `tools/Junkbot3D/Models`) into an `SCNNode` with local +Y up
  /// (LDraw's own +Y points down; every other mesh in this tool - `BrickGeometry`,
  /// `CharacterGeometry` - treats +Y as up, so the result is wrapped in a 180°-about-X parent to
  /// match). `extraSearchDirectory` (the input's own directory) is searched before the standard
  /// library layout under `ldrawRoot`, so an authored model's own sibling references resolve too.
  static func buildNode(
    text: String, extraSearchDirectory: URL?, colorCode: Int16, ldrawRoot: URL,
    colorTable: LDrawColorTable
  ) -> SCNNode? {
    var searchDirectories: [URL] = []
    if let extraSearchDirectory { searchDirectories.append(extraSearchDirectory) }
    searchDirectories.append(contentsOf: [
      ldrawRoot.appendingPathComponent("parts"),
      ldrawRoot.appendingPathComponent("parts/s"),
      ldrawRoot.appendingPathComponent("p"),
      ldrawRoot.appendingPathComponent("p/48"),
      ldrawRoot.appendingPathComponent("models"),
    ])
    let resolver = FileSystemPartResolver(searchDirectories: searchDirectories)
    let modelResolver = LDrawModelResolver(resolver: resolver, missingPartPolicy: .omit)

    guard let parsed = try? LDrawParser.parseAuto(text) else { return nil }
    let resolvedModel: ResolvedLDrawModel
    do {
      switch parsed {
      case .singleFile(let file):
        resolvedModel = try modelResolver.resolve(file)
      case .multiPartDocument(let document):
        resolvedModel = try modelResolver.resolve(document)
      }
    } catch {
      return nil
    }

    let defaultColor =
      colorTable.color(forCode: colorCode)
      ?? LDrawResolvedColor(
        name: "Light_Grey", code: 7, red: 138, green: 146, blue: 141,
        edgeRed: 51, edgeGreen: 51, edgeBlue: 51)
    let builder = LDrawSceneBuilder(options: .init(colorTable: colorTable, defaultColor: defaultColor))
    let node = builder.buildNode(from: resolvedModel)

    let wrapper = SCNNode()
    node.eulerAngles.x = .pi
    wrapper.addChildNode(node)
    return wrapper
  }
}
