// Offline 3D-preview/export tool for the low-poly LEGO rendering refactor (Phase 1). Three modes:
//
//   Level mode: loads a *real* level's entities through JunkbotCore's real parser/simulation
//   setup (the same data the live game uses) and builds a low-poly SceneKit scene from them.
//     swift run --package-path tools/Junkbot3D Junkbot3D <repo_root> <level.txt> <output.(png|usdz|scn)>
//
//   LDraw part mode: loads one real official LDraw part (from the library downloaded to
//   tools/Junkbot3D/LDraw/ldraw, via swift-lego-draw - see LDrawSupport.swift) by filename, e.g.
//   "3001.dat" (2x4 brick) or "3815.dat" (minifig legs), for previewing real parts standalone.
//     swift run --package-path tools/Junkbot3D Junkbot3D <repo_root> --part <name.dat> [colorCode] <output.(png|usdz|scn)>
//
//   LDraw model mode: loads one of our own authored `.ldr` models (tools/Junkbot3D/Models/*.ldr -
//   real official parts assembled to represent a game entity), for previewing/iterating on them
//   standalone before wiring into SceneBuilder.
//     swift run --package-path tools/Junkbot3D Junkbot3D <repo_root> --model <name.ldr> <output.(png|usdz|scn)>
//
// Output format is chosen by the output path's extension:
//   .png          - a single rendered snapshot (art-direction iteration loop)
//   .usdz / .scn  - the actual 3D scene/model, openable in macOS Quick Look/AR Quick Look, Preview,
//                   Reality Composer, Blender (via USD import), etc.

import AppKit
import Foundation
import JunkbotCore
import SceneKit

let usage = "usage:\n" +
  "  Junkbot3D <repo_root> <level.txt> <output.(png|usdz|scn)> [--front] [--frame N]\n" +
  "  Junkbot3D <repo_root> --part <name.dat> [colorCode] <output.(png|usdz|scn)>\n" +
  "  Junkbot3D <repo_root> --model <name.ldr> <output.(png|usdz|scn)>\n" +
  "  Junkbot3D <repo_root> --bbox <name.dat>\n" +
  "  Junkbot3D <repo_root> --bake-all <output_dir>\n" +
  "\n" +
  "  --front renders the real 2D game's actual look: a straight (non-rotated) camera plus the\n" +
  "  janitorial-android reference's oblique depth shear, instead of the default isometric angle.\n" +
  "\n" +
  "  --bake-all writes one bottom-center-anchored, game-scaled .scn per entity type with an\n" +
  "  authored .ldr model (see SceneBuilder.ldrawModelName's list) - for bundling into the live\n" +
  "  Darwin app, which can't ship the 600MB LDraw library or parse .ldr files at runtime.\n"

// Bakes every entity type's real-parts model to a bundleable .scn file, using the exact same
// `LDrawModel.node` anchor/scale logic the offline level-preview path uses, so the live app's
// bundled assets are pixel-for-pixel what this tool already renders. Dimensions match
// `EntityFactory.swift`'s `make*` constructors exactly (each entity type has one fixed size).
if CommandLine.arguments.count == 4, CommandLine.arguments[2] == "--bake-all" {
  let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
  let outputDir = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
  try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
  let ldrawRoot = repoRoot.appendingPathComponent("tools/Junkbot3D/LDraw/ldraw")
  let colorTable = LDrawSupport.colorTable(ldrawRoot: ldrawRoot)

  // (model name, entity width in game units, entity height in game units) - CELL_W=15, CELL_H=18.
  let entries: [(name: String, width: CGFloat, height: CGFloat)] = [
    ("junkbot", 2 * 15, 4 * 18),
    ("bin", 2 * 15, 3 * 18),
    ("gearbot", 2 * 15, 2 * 18),
    ("climbbot", 2 * 15, 2 * 18),
    ("flybot", 2 * 15, 2 * 18),
    ("eyebot", 2 * 15, 2 * 18),
    ("crate", 3 * 15, 2 * 18),
    ("fire", 4 * 15, 1 * 18),
    ("fan", 4 * 15, 1 * 18),
    ("switch", 2 * 15, 1 * 18),
    ("pipe", 2 * 15, 1 * 18),
    ("shield", 2 * 15, 1 * 18),
    ("teleport", 4 * 15, 1 * 18),
    ("laser", 2 * 15, 1 * 18),
    ("jump", 2 * 15, 1 * 18),
  ]

  var failures = 0
  for entry in entries {
    guard
      let node = LDrawModel.node(
        named: entry.name, entityWidth: entry.width, entityHeight: entry.height, repoRoot: repoRoot,
        ldrawRoot: ldrawRoot, colorTable: colorTable)
    else {
      FileHandle.standardError.write(Data("error: failed to bake '\(entry.name)'\n".utf8))
      failures += 1
      continue
    }
    let bakedScene = SCNScene()
    bakedScene.rootNode.addChildNode(node)
    let url = outputDir.appendingPathComponent("\(entry.name).scn")
    guard bakedScene.write(to: url, options: nil, delegate: nil, progressHandler: nil) else {
      FileHandle.standardError.write(Data("error: failed to write \(url.path)\n".utf8))
      failures += 1
      continue
    }
    print("Junkbot3D: baked \(entry.name).scn")
  }
  exit(failures == 0 ? 0 : 1)
}

/// Locates an official part's file under the standard LDraw library layout (`parts/`,
/// `parts/s/`, `p/`, `p/48/`), for the two modes (`--bbox`, `--part`) that need to read one by
/// bare filename rather than through swift-lego-draw's own resolver (which only kicks in once
/// we're already inside `LDrawSupport.buildNode`'s parse+resolve pipeline).
func findPartURL(named name: String, ldrawRoot: URL) -> URL? {
  for dir in ["parts", "parts/s", "p", "p/48"] {
    let candidate = ldrawRoot.appendingPathComponent(dir).appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
  }
  return nil
}

// Quick dimension lookup for authoring .ldr models (stacking parts needs their real Y extent,
// not a guess) - prints the part's bounding box (in LDraw's own Y-down coordinates, i.e. before
// this tool's usual up-flip) and exits, no output file needed.
if CommandLine.arguments.count == 4, CommandLine.arguments[2] == "--bbox" {
  let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
  let partName = CommandLine.arguments[3]
  let ldrawRoot = repoRoot.appendingPathComponent("tools/Junkbot3D/LDraw/ldraw")
  let colorTable = LDrawSupport.colorTable(ldrawRoot: ldrawRoot)
  guard let partURL = findPartURL(named: partName, ldrawRoot: ldrawRoot),
    let text = try? String(contentsOf: partURL, encoding: .utf8),
    let node = LDrawSupport.buildNode(
      text: text, extraSearchDirectory: nil, colorCode: 4, ldrawRoot: ldrawRoot,
      colorTable: colorTable),
    let childGeometryNode = node.childNodes.first
  else {
    FileHandle.standardError.write(Data("error: failed to load '\(partName)'\n".utf8))
    exit(1)
  }
  // `node` is the up-flip wrapper (see `LDrawSupport.buildNode`) - report the pre-flip child's
  // own bounding box, which is in LDraw's native Y-down space (matches the numbers in .dat files).
  let (min, max) = childGeometryNode.boundingBox
  print("\(partName): x=[\(min.x),\(max.x)] y=[\(min.y),\(max.y)] z=[\(min.z),\(max.z)]")
  exit(0)
}

guard CommandLine.arguments.count >= 4 else {
  FileHandle.standardError.write(Data(usage.utf8))
  exit(2)
}
let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])

/// A scene containing just `node`, lit and framed by an orthographic camera sized to its bounding
/// box - the standalone single-part/model preview used by `--part` and `--model`.
func standalonePreviewScene(for node: SCNNode) -> (scene: SCNScene, camera: SCNNode) {
  let builtScene = SCNScene()
  builtScene.rootNode.addChildNode(node)
  let ambient = SCNLight()
  ambient.type = .ambient
  ambient.color = Palette.rgb(0xB0, 0xB0, 0xB8)
  let ambientNode = SCNNode()
  ambientNode.light = ambient
  builtScene.rootNode.addChildNode(ambientNode)
  let sun = SCNLight()
  sun.type = .directional
  sun.color = Palette.rgb(0xFF, 0xFF, 0xF0)
  let sunNode = SCNNode()
  sunNode.light = sun
  sunNode.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
  builtScene.rootNode.addChildNode(sunNode)

  let (min, max) = node.boundingBox
  let span = Swift.max(max.x - min.x, Swift.max(max.y - min.y, max.z - min.z))
  let camera = SCNCamera()
  camera.usesOrthographicProjection = true
  camera.orthographicScale = Double(span) * 0.8
  camera.zNear = 1
  camera.zFar = 4000
  let builtCameraNode = SCNNode()
  builtCameraNode.camera = camera
  let distance = CGFloat(span) * 3
  builtCameraNode.position = SCNVector3(distance * 0.5, distance * 0.42, distance * 0.75)
  builtCameraNode.look(at: SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2))
  builtScene.rootNode.addChildNode(builtCameraNode)
  return (builtScene, builtCameraNode)
}

let scene: SCNScene
let cameraNode: SCNNode
let outputPath: String

if CommandLine.arguments[2] == "--part" {
  guard CommandLine.arguments.count == 5 || CommandLine.arguments.count == 6 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
  }
  let partName = CommandLine.arguments[3]
  let colorCode: Int16
  if CommandLine.arguments.count == 6 {
    colorCode = Int16(CommandLine.arguments[4]) ?? 4
    outputPath = CommandLine.arguments[5]
  } else {
    colorCode = 4  // red, LDraw's conventional default preview color
    outputPath = CommandLine.arguments[4]
  }

  let ldrawRoot = repoRoot.appendingPathComponent("tools/Junkbot3D/LDraw/ldraw")
  let colorTable = LDrawSupport.colorTable(ldrawRoot: ldrawRoot)
  guard let partURL = findPartURL(named: partName, ldrawRoot: ldrawRoot),
    let text = try? String(contentsOf: partURL, encoding: .utf8),
    let partNode = LDrawSupport.buildNode(
      text: text, extraSearchDirectory: nil, colorCode: colorCode, ldrawRoot: ldrawRoot,
      colorTable: colorTable)
  else {
    FileHandle.standardError.write(
      Data("error: failed to load LDraw part '\(partName)' from \(ldrawRoot.path)\n".utf8))
    exit(1)
  }

  print("Junkbot3D: loaded LDraw part '\(partName)' (color \(colorCode))")
  (scene, cameraNode) = standalonePreviewScene(for: partNode)
} else if CommandLine.arguments[2] == "--model" {
  guard CommandLine.arguments.count == 5 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
  }
  let modelName = CommandLine.arguments[3]
  outputPath = CommandLine.arguments[4]

  let ldrawRoot = repoRoot.appendingPathComponent("tools/Junkbot3D/LDraw/ldraw")
  let colorTable = LDrawSupport.colorTable(ldrawRoot: ldrawRoot)
  let modelsDirectory = repoRoot.appendingPathComponent("tools/Junkbot3D/Models")
  let modelURL = modelsDirectory.appendingPathComponent(modelName)
  guard let text = try? String(contentsOf: modelURL, encoding: .utf8),
    let modelNode = LDrawSupport.buildNode(
      text: text, extraSearchDirectory: modelsDirectory, colorCode: 16, ldrawRoot: ldrawRoot,
      colorTable: colorTable)
  else {
    FileHandle.standardError.write(
      Data("error: failed to load LDraw model '\(modelName)' from \(modelURL.path)\n".utf8))
    exit(1)
  }

  print("Junkbot3D: loaded LDraw model '\(modelName)'")
  (scene, cameraNode) = standalonePreviewScene(for: modelNode)
} else {
  let levelPath = CommandLine.arguments[2]
  guard CommandLine.arguments.count >= 4 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
  }
  outputPath = CommandLine.arguments[3]
  let trailingArgs = Array(CommandLine.arguments.dropFirst(4))
  let useFrontCamera = trailingArgs.contains("--front")
  // `--frame N` overrides every entity's `animationFrame` after loading, for rendering a single
  // pose out of a walk cycle (`CharacterGeometry.junkbot`'s procedural leg-swing/bob rig) instead
  // of whatever frame 0 (the level's just-loaded rest state) happens to look like.
  let overrideFrame: Int32? = {
    guard let flagIndex = trailingArgs.firstIndex(of: "--frame"),
      flagIndex + 1 < trailingArgs.count, let value = Int32(trailingArgs[flagIndex + 1])
    else { return nil }
    return value
  }()

  let levelURL =
    levelPath.hasPrefix("/") ? URL(fileURLWithPath: levelPath) : repoRoot.appendingPathComponent(levelPath)

  guard var levelText = try? String(contentsOf: levelURL, encoding: .utf8) else {
    FileHandle.standardError.write(Data("error: unreadable level file \(levelURL.path)\n".utf8))
    exit(1)
  }
  if levelText.hasPrefix("\u{FEFF}") { levelText.removeFirst() }

  let engine = GameEngine()
  engine.loadLevel(fromText: levelText)
  if let overrideFrame {
    engine.entities = engine.entities.map { entity in
      var entity = entity
      entity.animationFrame = overrideFrame
      return entity
    }
  }

  print("Junkbot3D: loaded \(engine.entities.count) entities, bounds=\(String(describing: engine.levelBounds))")

  let ldrawRoot = repoRoot.appendingPathComponent("tools/Junkbot3D/LDraw/ldraw")
  let colorTable = LDrawSupport.colorTable(ldrawRoot: ldrawRoot)
  let builtScene = SceneBuilder.makeScene(
    entities: engine.entities, bounds: engine.levelBounds, repoRoot: repoRoot, ldrawRoot: ldrawRoot,
    colorTable: colorTable, obliqueShear: useFrontCamera)
  let builtCameraNode = useFrontCamera
    ? SceneBuilder.frontCameraNode(entities: engine.entities, bounds: engine.levelBounds)
    : SceneBuilder.framingCameraNode(entities: engine.entities, bounds: engine.levelBounds)
  builtScene.rootNode.addChildNode(builtCameraNode)
  scene = builtScene
  cameraNode = builtCameraNode
}

let outputURL = URL(fileURLWithPath: outputPath)
switch outputURL.pathExtension.lowercased() {
case "usdz", "scn":
  guard scene.write(to: outputURL, options: nil, delegate: nil, progressHandler: nil) else {
    FileHandle.standardError.write(Data("error: failed to write \(outputURL.path)\n".utf8))
    exit(1)
  }
  print("Junkbot3D: wrote \(outputPath)")

case "png":
  let renderSize = CGSize(width: 1280, height: 960)
  let renderer = SCNRenderer(device: nil, options: nil)
  renderer.scene = scene
  renderer.pointOfView = cameraNode
  renderer.autoenablesDefaultLighting = false

  let image = renderer.snapshot(atTime: 0, with: renderSize, antialiasingMode: .none)
  guard let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let pngData = bitmap.representation(using: .png, properties: [:])
  else {
    FileHandle.standardError.write(Data("error: failed to encode PNG\n".utf8))
    exit(1)
  }
  try pngData.write(to: outputURL)
  print("Junkbot3D: wrote \(outputPath)")

default:
  FileHandle.standardError.write(
    Data("error: unsupported output extension '\(outputURL.pathExtension)' (use .png, .usdz, or .scn)\n".utf8))
  exit(2)
}
