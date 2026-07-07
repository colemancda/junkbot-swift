import Foundation
import LDrawMetal
import LegoDrawFile
import simd

/// Offline counterpart to `LDrawModel.swift`'s SceneKit path: parses/resolves the same authored
/// `.ldr` models, but flattens them into raw triangle data (via `swift-lego-draw`'s
/// `LDrawMetalFlattener`) instead of building an `SCNNode`, and serializes the result as JSON for
/// the live app's Metal renderer to load at runtime (which can't parse `.ldr`/ship the LDraw
/// library, same reason the SceneKit path bakes to `.scn` - see `main.swift`'s `--bake-all`).
@MainActor
enum Metal3DExporter {
  static let scale: Float = 0.75

  /// One rigid piece of a baked model: `vertices` are in the piece's own local space (untouched
  /// by this model's placement within its parent, so a piece that should rotate about its own
  /// pivot - currently only Junkbot's legs - can still do so at runtime), and `transform` (bakes
  /// together the LDraw-to-game-Y-up flip, `scale`, this model's bottom-center anchor offset, and
  /// - for a rigged piece - its placement translation within the parent model) maps those local
  /// vertices into the model's own entity-local space. Runtime composes
  /// `entityWorldTransform * transform * legRotation(animationFrame) * localVertex`.
  struct BakedSubmesh: Codable {
    var transform: [Float]  // float4x4, column-major, 16 floats
    var positions: [Float]  // 3 floats/vertex
    var normals: [Float]  // 3 floats/vertex
    var colors: [Float]  // 4 floats/vertex
  }

  struct BakedModel: Codable {
    var submeshes: [BakedSubmesh]
  }

  /// `name`/`entityWidth`/`entityHeight`/`repoRoot`/`ldrawRoot`/`colorTable` mirror
  /// `LDrawModel.node(named:...)`'s parameters exactly - same model file, same anchor convention.
  static func export(
    named name: String, entityWidth: Float, entityHeight: Float, repoRoot: URL, ldrawRoot: URL,
    colorTable: LDrawColorTable
  ) -> BakedModel? {
    let modelsDirectory = repoRoot.appendingPathComponent("tools/Junkbot3D/Models")
    let modelURL = modelsDirectory.appendingPathComponent("\(name).ldr")
    guard let text = try? String(contentsOf: modelURL, encoding: .utf8) else { return nil }

    var searchDirectories: [URL] = [modelsDirectory]
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
      case .singleFile(let file): resolvedModel = try modelResolver.resolve(file)
      case .multiPartDocument(let document): resolvedModel = try modelResolver.resolve(document)
      }
    } catch { return nil }

    let defaultColor =
      colorTable.color(forCode: 16)
      ?? LDrawResolvedColor(
        name: "Light_Grey", code: 7, red: 138, green: 146, blue: 141,
        edgeRed: 51, edgeGreen: 51, edgeBlue: 51)
    let flattener = LDrawMetalFlattener(colorTable: colorTable, defaultColor: defaultColor)

    // LDraw's own +Y points down; the SceneKit path compensates with a 180deg-about-X wrapper
    // (`LDrawSupport.buildNode`). Applied here as the first factor of every submesh's `transform`.
    let flipX = float4x4(diagonal: SIMD4<Float>(1, -1, -1, 1))

    // Junkbot is the only rigged model: `junkbot.ldr`'s top-level statements are its 6 subfile
    // placements (hips/rightLeg/leftLeg/body/head/lid, in that authored order - matches
    // `LDrawModel.swift`'s existing structural-index comment). Flatten each SEPARATELY, in its own
    // local space (not yet including its own placement transform), so a rigged piece can still be
    // rotated about its own pivot at runtime. Every other entity flattens as a single piece.
    let rawPieces: [(placement: float4x4, localVertices: [LDrawMetalVertex])]
    if name == "junkbot" {
      rawPieces = resolvedModel.children.compactMap { child in
        guard case .subfile(let t, let colorRef, _, let sub) = child else { return nil }
        // `flattener.flatten(sub)` alone would flatten `sub` with the exporter's *top-level*
        // `defaultColor` as the fallback for any of `sub`'s own color-16 ("current color",
        // inherit from the enclosing subfile reference) triangles - wrong, since each of
        // Junkbot's 6 top-level pieces has its OWN explicit color in `junkbot.ldr` (25 orange
        // body, 14 yellow lid, 71 gray legs/hips). Resolve `colorRef` against the top-level
        // default first (mirroring `LDrawMetalFlattener`'s own private `resolve`, which isn't
        // public) and flatten with THAT as the piece's own default, so pass-through triangles
        // inside the part inherit the correct color instead of the exporter's generic fallback.
        let pieceColor = resolveColor(colorRef, current: defaultColor, colorTable: colorTable)
        let pieceFlattener = LDrawMetalFlattener(colorTable: colorTable, defaultColor: pieceColor)
        return (float4x4(t), pieceFlattener.flatten(sub))
      }
    } else {
      rawPieces = [(matrix_identity_float4x4, flattener.flatten(resolvedModel))]
    }
    guard !rawPieces.isEmpty else { return nil }

    // Bottom-center anchor, replicating `LDrawModel.buildInstance` exactly: union bounding box of
    // every piece in "flip + scale applied, not yet anchored" space, then a translation so the
    // model's own bottom sits at local y = -entityHeight/2 and its horizontal center sits at local
    // x = 0 (z untouched - a model's own front/back placement is intentional, see
    // `LDrawModel.swift`). Applied once, uniformly, to every piece below.
    var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    var preAnchorTransforms: [float4x4] = []
    for (placement, vertices) in rawPieces {
      let preAnchor = float4x4(scale: scale) * flipX * placement
      preAnchorTransforms.append(preAnchor)
      for v in vertices {
        let pv = preAnchor * SIMD4<Float>(v.position, 1)
        let p = SIMD3<Float>(pv.x, pv.y, pv.z)
        minP = simd_min(minP, p)
        maxP = simd_max(maxP, p)
      }
    }
    let anchor = SIMD3<Float>(-(minP.x + maxP.x) / 2, -minP.y - entityHeight / 2, 0)
    let anchorTransform = float4x4(translation: anchor)

    let submeshes: [BakedSubmesh] = zip(rawPieces, preAnchorTransforms).map { piece, preAnchor in
      let transform = anchorTransform * preAnchor
      var positions: [Float] = []
      var normals: [Float] = []
      var colors: [Float] = []
      positions.reserveCapacity(piece.localVertices.count * 3)
      normals.reserveCapacity(piece.localVertices.count * 3)
      colors.reserveCapacity(piece.localVertices.count * 4)
      for v in piece.localVertices {
        positions.append(contentsOf: [v.position.x, v.position.y, v.position.z])
        normals.append(contentsOf: [v.normal.x, v.normal.y, v.normal.z])
        colors.append(contentsOf: [v.color.x, v.color.y, v.color.z, v.color.w])
      }
      let m = transform
      let columnMajor: [Float] = [
        m.columns.0.x, m.columns.0.y, m.columns.0.z, m.columns.0.w,
        m.columns.1.x, m.columns.1.y, m.columns.1.z, m.columns.1.w,
        m.columns.2.x, m.columns.2.y, m.columns.2.z, m.columns.2.w,
        m.columns.3.x, m.columns.3.y, m.columns.3.z, m.columns.3.w,
      ]
      return BakedSubmesh(transform: columnMajor, positions: positions, normals: normals, colors: colors)
    }

    return BakedModel(submeshes: submeshes)
  }
}

/// Mirrors `LDrawMetalFlattener`'s own private `resolve(_:current:)` exactly (not public, so this
/// tool needs its own copy to resolve a top-level piece's color *before* handing it to a fresh
/// `LDrawMetalFlattener` as that piece's own default - see the call site's comment above).
private func resolveColor(
  _ ref: LDrawColorReference, current: LDrawResolvedColor, colorTable: LDrawColorTable
) -> LDrawResolvedColor {
  switch ref {
  case .currentColor: return current
  case .edgeColor:
    return LDrawResolvedColor(
      name: current.name + " Edge", code: current.code,
      red: current.edgeRed, green: current.edgeGreen, blue: current.edgeBlue,
      alpha: current.edgeAlpha,
      edgeRed: current.edgeRed, edgeGreen: current.edgeGreen, edgeBlue: current.edgeBlue,
      edgeAlpha: current.edgeAlpha, finish: .solid)
  case .index(let code):
    return colorTable.color(forCode: code) ?? current
  case .direct(let r, let g, let b):
    return LDrawResolvedColor(
      name: "Direct", code: -1, red: r, green: g, blue: b, edgeRed: r, edgeGreen: g, edgeBlue: b)
  }
}

// MARK: - Matrix helpers

/// `Matrix4` stores rows `[a b c x; d e f y; g h i z; 0 0 0 1]` (see `LegoDrawFile`'s doc comment)
/// - `simd`'s `float4x4(columns:)` wants column vectors, so each of `Matrix4`'s rows becomes one
/// component spread across the three rotation/scale columns, with translation as the 4th column.
private func float4x4(_ m: Matrix4) -> float4x4 {
  float4x4(
    columns: (
      SIMD4<Float>(m.a, m.d, m.g, 0),
      SIMD4<Float>(m.b, m.e, m.h, 0),
      SIMD4<Float>(m.c, m.f, m.i, 0),
      SIMD4<Float>(m.x, m.y, m.z, 1)
    ))
}

private func float4x4(translation t: SIMD3<Float>) -> float4x4 {
  float4x4(
    columns: (
      SIMD4<Float>(1, 0, 0, 0),
      SIMD4<Float>(0, 1, 0, 0),
      SIMD4<Float>(0, 0, 1, 0),
      SIMD4<Float>(t.x, t.y, t.z, 1)
    ))
}

private func float4x4(scale s: Float) -> float4x4 {
  float4x4(diagonal: SIMD4<Float>(s, s, s, 1))
}
