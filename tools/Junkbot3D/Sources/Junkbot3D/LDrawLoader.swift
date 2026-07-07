import AppKit
import Foundation
import SceneKit

/// A 4x4 row-major affine transform, matching LDraw's own convention (an LDraw type-1 line's
/// `a b c d e f g h i` is a row-major 3x3 rotation/scale matrix, `x y z` is the translation).
/// `simd` isn't worth pulling in for this - subfile trees are only a few levels deep and each
/// part is a few hundred triangles at most.
private struct LMatrix {
  var m: [Double]  // row-major, 16 elements

  static let identity = LMatrix(
    m: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])

  /// From an LDraw type-1 line's 12 numeric fields (x y z, then a..i).
  static func fromLDraw(x: Double, y: Double, z: Double, a: Double, b: Double, c: Double, d: Double, e: Double, f: Double, g: Double, h: Double, i: Double) -> LMatrix {
    LMatrix(m: [a, b, c, x, d, e, f, y, g, h, i, z, 0, 0, 0, 1])
  }

  func multiplied(by other: LMatrix) -> LMatrix {
    var result = [Double](repeating: 0, count: 16)
    for row in 0..<4 {
      for col in 0..<4 {
        var sum = 0.0
        for k in 0..<4 { sum += m[row * 4 + k] * other.m[k * 4 + col] }
        result[row * 4 + col] = sum
      }
    }
    return LMatrix(m: result)
  }

  func apply(_ v: SCNVector3) -> SCNVector3 {
    let x = Double(v.x)
    let y = Double(v.y)
    let z = Double(v.z)
    return SCNVector3(
      Float(m[0] * x + m[1] * y + m[2] * z + m[3]),
      Float(m[4] * x + m[5] * y + m[6] * z + m[7]),
      Float(m[8] * x + m[9] * y + m[10] * z + m[11]))
  }
}

private struct LDrawTriangle {
  var v0, v1, v2: SCNVector3
  var colorCode: Int32
}

/// Loads real official LDraw parts (from the library downloaded to `tools/Junkbot3D/LDraw/ldraw`)
/// as low-poly `SCNNode`s, recursively resolving type-1 subfile references (bricks reference
/// subparts under `parts/s/`, and both parts and subparts reference primitives under `p/`) and
/// flattening type-3/4 (triangle/quad) geometry into one flat-shaded mesh - the LDraw-native
/// counterpart to this tool's procedural `BrickGeometry`/`CharacterGeometry`, for parts (minifig
/// legs, slopes, etc.) worth pulling in as the real thing instead of approximating.
///
/// Deliberately ignores type-2 (line) and type-5 (optional/conditional line) records - hard edges
/// are drawn by `EdgeOutline` instead, matching every other mesh this tool builds, and ignores BFC
/// winding directives (`0 BFC ...`) entirely: geometry is rendered double-sided
/// (`isDoubleSided = true`) so a wrong winding direction never culls a face invisible, at the cost
/// of occasionally-inverted per-face lighting on nonstandard/unofficial parts - an acceptable
/// tradeoff for a low-poly stylized renderer that isn't chasing photorealistic shading anyway.
enum LDrawLoader {
  /// Root of the extracted library, e.g. `<repoRoot>/tools/Junkbot3D/LDraw/ldraw`.
  static func load(partNamed partName: String, colorCode: Int32, ldrawRoot: URL, colorTable: LDrawColorTable) -> SCNNode? {
    var triangles: [LDrawTriangle] = []
    guard resolveAndCollect(fileName: partName, transform: .identity, currentColor: colorCode, ldrawRoot: ldrawRoot, into: &triangles) else {
      return nil
    }
    return finish(triangles, colorTable: colorTable)
  }

  /// Loads one of *our own* authored `.ldr` models (e.g. `tools/Junkbot3D/Models/bin.ldr` - a
  /// small scene of real official parts assembled to look like a game entity), given directly by
  /// path rather than resolved against the library's `parts`/`p`/etc. search dirs the way
  /// `load(partNamed:)` resolves official part references - only the model file's own type-1
  /// subfile references (which name real official parts) get resolved against `ldrawRoot`.
  static func loadModel(fileURL: URL, colorCode: Int32, ldrawRoot: URL, colorTable: LDrawColorTable) -> SCNNode? {
    var triangles: [LDrawTriangle] = []
    guard collect(fromFileAt: fileURL, transform: .identity, currentColor: colorCode, ldrawRoot: ldrawRoot, into: &triangles) else {
      return nil
    }
    return finish(triangles, colorTable: colorTable)
  }

  private static func finish(_ triangles: [LDrawTriangle], colorTable: LDrawColorTable) -> SCNNode? {
    guard !triangles.isEmpty else { return nil }
    let node = buildNode(from: triangles, colorTable: colorTable)

    // LDraw's coordinate system has +Y pointing *down* (studs point toward -Y); every LDraw-aware
    // renderer flips this on load (e.g. `three-stuff/3d-main.js`'s `model.rotation.x = Math.PI`
    // comment - "Convert from LDraw coordinates"). Wrap in a parent so callers get a node whose
    // local +Y is up, matching every other mesh (`BrickGeometry`, `CharacterGeometry`) in this
    // tool.
    let wrapper = SCNNode()
    node.eulerAngles.x = .pi
    wrapper.addChildNode(node)
    return wrapper
  }

  private static func resolveAndCollect(
    fileName: String, transform: LMatrix, currentColor: Int32, ldrawRoot: URL,
    into triangles: inout [LDrawTriangle]
  ) -> Bool {
    guard let url = resolveURL(fileName: fileName, ldrawRoot: ldrawRoot) else { return false }
    return collect(fromFileAt: url, transform: transform, currentColor: currentColor, ldrawRoot: ldrawRoot, into: &triangles)
  }

  private static func collect(
    fromFileAt url: URL, transform: LMatrix, currentColor: Int32, ldrawRoot: URL,
    into triangles: inout [LDrawTriangle]
  ) -> Bool {
    guard let rawText = try? String(contentsOf: url, encoding: .utf8) else { return false }
    // Every official part file uses CRLF line endings; splitting on "\n" alone leaves a trailing
    // "\r" glued onto each line's last token, which silently fails Double parsing on every single
    // geometry line (the bug this replaced - 0 triangles collected from any file).
    let text = rawText.replacingOccurrences(of: "\r", with: "")

    for rawLine in text.split(separator: "\n") {
      let tokens = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
      guard let lineType = tokens.first else { continue }

      switch lineType {
      case "1":
        guard tokens.count >= 15 else { continue }
        guard let colorRaw = Int32(tokens[1]) else { continue }
        let color = colorRaw == 16 ? currentColor : colorRaw
        guard let nums = parseDoubles(tokens[2..<14]) else { continue }
        let sub = LMatrix.fromLDraw(
          x: nums[0], y: nums[1], z: nums[2], a: nums[3], b: nums[4], c: nums[5], d: nums[6],
          e: nums[7], f: nums[8], g: nums[9], h: nums[10], i: nums[11])
        let combined = transform.multiplied(by: sub)
        // The subfile name is everything after the 13 numeric fields (filenames can contain
        // spaces), joined back with single spaces.
        let subFile = tokens[14...].joined(separator: " ")
        _ = resolveAndCollect(
          fileName: subFile, transform: combined, currentColor: color, ldrawRoot: ldrawRoot,
          into: &triangles)

      case "3":
        guard tokens.count >= 10, let colorRaw = Int32(tokens[1]),
          let nums = parseDoubles(tokens[2..<11])
        else { continue }
        let color = colorRaw == 16 ? currentColor : colorRaw
        let p0 = transform.apply(SCNVector3(Float(nums[0]), Float(nums[1]), Float(nums[2])))
        let p1 = transform.apply(SCNVector3(Float(nums[3]), Float(nums[4]), Float(nums[5])))
        let p2 = transform.apply(SCNVector3(Float(nums[6]), Float(nums[7]), Float(nums[8])))
        triangles.append(LDrawTriangle(v0: p0, v1: p1, v2: p2, colorCode: color))

      case "4":
        guard tokens.count >= 13, let colorRaw = Int32(tokens[1]),
          let nums = parseDoubles(tokens[2..<14])
        else { continue }
        let color = colorRaw == 16 ? currentColor : colorRaw
        let p0 = transform.apply(SCNVector3(Float(nums[0]), Float(nums[1]), Float(nums[2])))
        let p1 = transform.apply(SCNVector3(Float(nums[3]), Float(nums[4]), Float(nums[5])))
        let p2 = transform.apply(SCNVector3(Float(nums[6]), Float(nums[7]), Float(nums[8])))
        let p3 = transform.apply(SCNVector3(Float(nums[9]), Float(nums[10]), Float(nums[11])))
        triangles.append(LDrawTriangle(v0: p0, v1: p1, v2: p2, colorCode: color))
        triangles.append(LDrawTriangle(v0: p0, v1: p2, v2: p3, colorCode: color))

      default:
        continue  // 0 (comment/meta), 2 (line), 5 (optional line): not geometry we draw.
      }
    }
    return true
  }

  private static func parseDoubles(_ tokens: ArraySlice<String>) -> [Double]? {
    var result: [Double] = []
    result.reserveCapacity(tokens.count)
    for t in tokens {
      guard let v = Double(t) else { return nil }
      result.append(v)
    }
    return result
  }

  /// LDraw file-reference resolution order: normalize `\`-separated paths (Windows-style, as
  /// written in every official part file) to `/`, then try, in order: `parts/`, `parts/s/`
  /// (subparts), `p/` (primitives), `p/48/` (hi-res primitives), `models/`.
  private static func resolveURL(fileName: String, ldrawRoot: URL) -> URL? {
    let normalized = fileName.replacingOccurrences(of: "\\", with: "/")
    let candidateDirs = ["parts", "parts/s", "p", "p/48", "models"]
    for dir in candidateDirs {
      let candidate = ldrawRoot.appendingPathComponent(dir).appendingPathComponent(normalized)
      if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }
    return nil
  }

  /// Flat-shaded (hard-edged) mesh, one vertex triple per triangle so each face gets its own
  /// normal - matching the faceted low-poly look everywhere else in this tool - plus a per-vertex
  /// color source so the whole part is one draw call regardless of how many LDraw colors it uses,
  /// rather than a single mesh with a per-vertex `.color` geometry source: an early version of
  /// this loader used a custom-`Data`-backed color source instead, matching every vertex/normal
  /// source's construction pattern, and SceneKit silently discarded the *entire* geometry with it
  /// attached (no error - `snapshot` just came back fully transparent) - some incompatibility in
  /// that construction is invisible to inspection, so grouping by color into ordinary per-element
  /// `SCNMaterial`s (the same proven pattern `BrickGeometry`/`CharacterGeometry` use for
  /// `SCNBox.materials`) sidesteps it entirely.
  private static func buildNode(from triangles: [LDrawTriangle], colorTable: LDrawColorTable) -> SCNNode {
    var positions: [SCNVector3] = []
    var normals: [SCNVector3] = []
    // Indices grouped by color code, preserving first-seen order so `elements`/`materials` line
    // up positionally.
    var order: [Int32] = []
    var indicesByColor: [Int32: [Int32]] = [:]

    positions.reserveCapacity(triangles.count * 3)
    normals.reserveCapacity(triangles.count * 3)

    for tri in triangles {
      let ab = SCNVector3(tri.v1.x - tri.v0.x, tri.v1.y - tri.v0.y, tri.v1.z - tri.v0.z)
      let ac = SCNVector3(tri.v2.x - tri.v0.x, tri.v2.y - tri.v0.y, tri.v2.z - tri.v0.z)
      let nx = ab.y * ac.z - ab.z * ac.y
      let ny = ab.z * ac.x - ab.x * ac.z
      let nz = ab.x * ac.y - ab.y * ac.x
      let len = max(0.0001, sqrt(nx * nx + ny * ny + nz * nz))
      let normal = SCNVector3(nx / len, ny / len, nz / len)

      let base = Int32(positions.count)
      positions.append(contentsOf: [tri.v0, tri.v1, tri.v2])
      normals.append(contentsOf: [normal, normal, normal])

      if indicesByColor[tri.colorCode] == nil {
        order.append(tri.colorCode)
        indicesByColor[tri.colorCode] = []
      }
      indicesByColor[tri.colorCode]!.append(contentsOf: [base, base + 1, base + 2])
    }

    let vertexSource = SCNGeometrySource(vertices: positions)
    let normalSource = SCNGeometrySource(normals: normals)
    let elements = order.map { SCNGeometryElement(indices: indicesByColor[$0]!, primitiveType: .triangles) }
    let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: elements)
    geometry.materials = order.map { code in
      let material = SCNMaterial()
      material.diffuse.contents = colorTable.color(for: code)
      material.lightingModel = .lambert
      material.isDoubleSided = true  // BFC winding isn't parsed - see this file's header comment.
      material.locksAmbientWithDiffuse = true
      return material
    }

    return SCNNode(geometry: geometry)
  }
}
