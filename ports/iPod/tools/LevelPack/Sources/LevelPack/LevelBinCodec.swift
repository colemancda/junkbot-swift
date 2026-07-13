// levels.bin codec for the iPod port -- shared between the host-side encoder
// (LevelPack's main.swift, which writes the file at build time) and the
// on-device decoder (this same file is compiled into the armv4t plugin by
// ports/iPod/Makefile). Keeping encode and decode adjacent in one file is what
// keeps the field order in sync; LevelPack additionally round-trips the blob
// through this decoder and diffs it against the source data after writing.
//
// Junkbot's level data is ~1.6MB as compiled-in Swift (the generated
// entity-builder code every other port embeds), which alone overflows a
// Rockbox plugin's 512KB code budget -- so on this port levels are an asset
// file, loaded from /.rockbox/junkbot/levels.bin into the audio buffer next
// to sprites.bin, and decoded per level on demand.
//
// Format (all values little-endian Int32/UInt32, all offsets 4-byte aligned):
//
//   header:   magic 'JBLV', version (1), levelCount,
//             levelCount x byte offset (from file start) of each level record
//   level:    par (Int32.max = none), hasBounds, bounds x/y/w/h,
//             backdropSpriteID, title (string), hint (string),
//             backgroundDecals (decal list), decals (decal list),
//             entityCount, entityCount x entity record
//   string:   byteLen including NUL terminator, bytes, zero-padded to 4
//             (NUL-terminated in place so the C host can use the pointer as-is)
//   decals:   count, count x { x, y, spriteID }
//   entity:   entityFieldCount x Int32 (Bools as 0/1, EntityType as rawValue),
//             in the exact order of encodeEntity/decodeEntity below

// On the host this file is part of the LevelPack executable, with the engine a
// separate module; on the device build everything (engine + port + this file)
// compiles as one module, so there's nothing to import.
#if canImport(JunkbotCore)
  import JunkbotCore
#endif

let levelBinMagic: UInt32 = 0x564C_424A  // 'JBLV' little-endian
let levelBinVersion: UInt32 = 1
/// Every stored property of `Entity`, in encode order. LevelPack asserts this
/// against `Mirror(reflecting: Entity).children.count` so adding a field to
/// `Entity` without updating the codec fails the asset build instead of
/// silently corrupting on-device decodes.
let entityFieldCount = 41

// MARK: - Entity field order (the single source of truth)

#if !hasFeature(Embedded)
/// Appends every `Entity` field to `out`, in declaration order.
func encodeEntity(_ e: Entity, into out: inout [UInt8]) {
  func put(_ v: Int32) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
  func put(_ b: Bool) { put(Int32(b ? 1 : 0)) }
  put(e.id)
  put(Int32(e.type.rawValue))
  put(e.x)
  put(e.y)
  put(e.width)
  put(e.height)
  put(e.grabbed)
  put(e.fixed)
  put(e.floating)
  put(e.wasFloating)
  put(e.removeBeforeRender)
  put(e.facing)
  put(e.facingY)
  put(e.animationFrame)
  put(e.widthInStuds)
  put(e.colorIndex)
  put(e.armored)
  put(e.losingShield)
  put(e.losingShieldTime)
  put(e.gettingShield)
  put(e.dying)
  put(e.dyingFromWater)
  put(e.dead)
  put(e.collectingBin)
  put(e.headLoaded)
  put(e.momentumX)
  put(e.momentumY)
  put(e.scaredy)
  put(e.on)
  put(e.used)
  put(e.switchID)
  put(e.steppedOn)
  put(e.teleportID)
  put(e.timer)
  put(e.blocked)
  put(e.energy)
  put(e.active)
  put(e.activeTimer)
  put(e.splashing)
  put(e.grabOffsetX)
  put(e.grabOffsetY)
}
#endif

/// Reads one entity record (mirror image of `encodeEntity` -- keep the field
/// order identical). `cursor` is a byte offset into `base`, advanced past the
/// record.
func decodeEntity(from base: UnsafeRawPointer, at cursor: inout Int) -> Entity {
  func i32() -> Int32 {
    let v = base.loadUnaligned(fromByteOffset: cursor, as: Int32.self)
    cursor += 4
    return Int32(littleEndian: v)
  }
  func flag() -> Bool { i32() != 0 }
  let id = i32()
  let type = EntityType(rawValue: UInt8(truncatingIfNeeded: i32())) ?? .unknown
  let x = i32()
  let y = i32()
  let width = i32()
  let height = i32()
  var e = Entity(id: id, type: type, x: x, y: y, width: width, height: height)
  e.grabbed = flag()
  e.fixed = flag()
  e.floating = flag()
  e.wasFloating = flag()
  e.removeBeforeRender = flag()
  e.facing = i32()
  e.facingY = i32()
  e.animationFrame = i32()
  e.widthInStuds = i32()
  e.colorIndex = i32()
  e.armored = flag()
  e.losingShield = flag()
  e.losingShieldTime = i32()
  e.gettingShield = flag()
  e.dying = flag()
  e.dyingFromWater = flag()
  e.dead = flag()
  e.collectingBin = flag()
  e.headLoaded = flag()
  e.momentumX = i32()
  e.momentumY = i32()
  e.scaredy = flag()
  e.on = flag()
  e.used = flag()
  e.switchID = i32()
  e.steppedOn = flag()
  e.teleportID = i32()
  e.timer = i32()
  e.blocked = flag()
  e.energy = i32()
  e.active = flag()
  e.activeTimer = i32()
  e.splashing = flag()
  e.grabOffsetX = i32()
  e.grabOffsetY = i32()
  return e
}

// MARK: - Whole-file encoder (host only)

#if !hasFeature(Embedded)
/// Serializes `levels` into the levels.bin byte layout described above.
func encodeLevelBin(_ levels: [EmbeddedLevel]) -> [UInt8] {
  var out: [UInt8] = []
  func put(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
  func put(_ v: Int32) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
  func putString(_ s: String) {
    let bytes = Array(s.utf8) + [0]  // NUL-terminated for the C host
    put(UInt32(bytes.count))
    out.append(contentsOf: bytes)
    while out.count % 4 != 0 { out.append(0) }
  }
  func putDecals(_ decals: [DecalInstance]) {
    put(UInt32(decals.count))
    for d in decals {
      put(d.x)
      put(d.y)
      put(d.spriteID)
    }
  }

  put(levelBinMagic)
  put(levelBinVersion)
  put(UInt32(levels.count))
  let offsetTableStart = out.count
  for _ in levels { put(UInt32(0)) }  // patched below

  for (index, level) in levels.enumerated() {
    let offset = UInt32(out.count)
    withUnsafeBytes(of: offset.littleEndian) { bytes in
      for (i, b) in bytes.enumerated() { out[offsetTableStart + index * 4 + i] = b }
    }
    put(level.par)
    if let b = level.bounds {
      put(UInt32(1))
      put(b.x)
      put(b.y)
      put(b.width)
      put(b.height)
    } else {
      put(UInt32(0))
      put(Int32(0))
      put(Int32(0))
      put(Int32(0))
      put(Int32(0))
    }
    put(level.backdropSpriteID)
    putString(level.title.description)
    putString(level.hint.description)
    putDecals(level.backgroundDecals)
    putDecals(level.decals)
    let entities = level.makeEntities()
    put(UInt32(entities.count))
    for e in entities { encodeEntity(e, into: &out) }
  }
  return out
}
#endif

// MARK: - Decoder (device + host verification)

/// Random access into a loaded levels.bin. The pointer must stay valid for the
/// catalog's lifetime (on device it's the audio buffer, which is).
struct LevelBinCatalog {
  let base: UnsafeRawPointer
  let count: Int

  /// Validates the header; returns nil on a bad magic/version (e.g. a stale
  /// levels.bin from an older build).
  init?(base: UnsafeRawPointer, byteCount: Int) {
    guard byteCount >= 12,
      UInt32(littleEndian: base.loadUnaligned(fromByteOffset: 0, as: UInt32.self)) == levelBinMagic,
      UInt32(littleEndian: base.loadUnaligned(fromByteOffset: 4, as: UInt32.self)) == levelBinVersion
    else { return nil }
    self.base = base
    self.count = Int(UInt32(littleEndian: base.loadUnaligned(fromByteOffset: 8, as: UInt32.self)))
  }

  private func levelOffset(_ index: Int) -> Int {
    Int(UInt32(littleEndian: base.loadUnaligned(fromByteOffset: 12 + index * 4, as: UInt32.self)))
  }

  /// Everything about one level except its entities (decoded separately since
  /// only `entities(_:)`'s result is large).
  struct Meta {
    var par: Int32
    var bounds: LevelBounds?
    var backdropSpriteID: Int32
    /// NUL-terminated UTF-8, pointing into the loaded file.
    var title: UnsafePointer<CChar>
    var hint: UnsafePointer<CChar>
    var backgroundDecals: [DecalInstance]
    var decals: [DecalInstance]
    /// Byte offset of the entity records (cached so `entities(_:)` doesn't re-walk).
    var entityCursor: Int
    var entityCount: Int
  }

  func meta(_ index: Int) -> Meta {
    var cursor = levelOffset(index)
    func i32() -> Int32 {
      let v = base.loadUnaligned(fromByteOffset: cursor, as: Int32.self)
      cursor += 4
      return Int32(littleEndian: v)
    }
    func u32() -> Int { Int(UInt32(bitPattern: i32())) }
    func string() -> UnsafePointer<CChar> {
      let byteLen = u32()
      let pointer = (base + cursor).assumingMemoryBound(to: CChar.self)
      cursor += (byteLen + 3) & ~3
      return pointer
    }
    func decals() -> [DecalInstance] {
      let count = u32()
      var result: [DecalInstance] = []
      result.reserveCapacity(count)
      for _ in 0..<count {
        let x = i32()
        let y = i32()
        let spriteID = i32()
        result.append(DecalInstance(x: x, y: y, spriteID: spriteID))
      }
      return result
    }

    let par = i32()
    let hasBounds = u32() != 0
    let bx = i32(), by = i32(), bw = i32(), bh = i32()
    let backdrop = i32()
    let title = string()
    let hint = string()
    let backgroundDecals = decals()
    let nearDecals = decals()
    let entityCount = u32()
    return Meta(
      par: par,
      bounds: hasBounds ? LevelBounds(x: bx, y: by, width: bw, height: bh) : nil,
      backdropSpriteID: backdrop,
      title: title, hint: hint,
      backgroundDecals: backgroundDecals, decals: nearDecals,
      entityCursor: cursor, entityCount: entityCount)
  }

  func entities(_ meta: Meta) -> [Entity] {
    var cursor = meta.entityCursor
    var result: [Entity] = []
    result.reserveCapacity(meta.entityCount)
    for _ in 0..<meta.entityCount {
      result.append(decodeEntity(from: base, at: &cursor))
    }
    return result
  }
}
