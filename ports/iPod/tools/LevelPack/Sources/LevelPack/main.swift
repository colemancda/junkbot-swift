// Build-time level packer for the iPod port.
//
// Every other port compiles the pre-parsed campaign levels in as generated
// Swift (`Generated/LevelData.swift`'s `embeddedLevels`), but that's ~1.6MB of
// code -- more than three times a Rockbox plugin's entire 512KB budget. This
// tool serializes the same `embeddedLevels` into `levels.bin` instead
// (LevelBinCodec.swift, compiled both here and into the plugin), which the
// device loads from /.rockbox/junkbot/levels.bin at startup.
//
// After writing, the blob is decoded back through the same decoder the device
// uses and diffed field-by-field against the source data, so an encoder/
// decoder mismatch (e.g. a new Entity field missing from the codec) fails this
// build instead of corrupting on-device.
//
// Usage: swift run LevelPack <output.bin>

import Foundation
import JunkbotCore

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("usage: LevelPack <output.bin>\n".utf8))
  exit(2)
}
let outputPath = CommandLine.arguments[1]

// Guard the codec against Entity gaining fields it doesn't know about: the
// stored-property count must match the codec's field list exactly.
let storedPropertyCount = Mirror(reflecting: Entity(id: 0, type: .brick, x: 0, y: 0, width: 0, height: 0)).children.count
guard storedPropertyCount == entityFieldCount else {
  let message =
    "error: Entity has \(storedPropertyCount) stored properties but LevelBinCodec.swift "
    + "encodes \(entityFieldCount) -- update encodeEntity/decodeEntity/entityFieldCount\n"
  FileHandle.standardError.write(Data(message.utf8))
  exit(1)
}

let levels = embeddedLevels
let blob = encodeLevelBin(levels)

// Round-trip verification through the device decoder.
let failures: Int = blob.withUnsafeBytes { raw in
  guard let catalog = LevelBinCatalog(base: raw.baseAddress!, byteCount: raw.count),
    catalog.count == levels.count
  else {
    FileHandle.standardError.write(Data("error: reloaded blob failed header validation\n".utf8))
    exit(1)
  }
  var failures = 0
  for (index, level) in levels.enumerated() {
    let meta = catalog.meta(index)
    let decodedEntities = catalog.entities(meta)
    let sourceEntities = level.makeEntities()

    func check(_ ok: Bool, _ what: String) {
      if !ok {
        FileHandle.standardError.write(Data("mismatch: level \(index) \(what)\n".utf8))
        failures += 1
      }
    }
    check(meta.par == level.par, "par")
    check(meta.backdropSpriteID == level.backdropSpriteID, "backdrop")
    check(String(cString: meta.title) == level.title.description, "title")
    check(String(cString: meta.hint) == level.hint.description, "hint")
    check(meta.bounds?.x == level.bounds?.x && meta.bounds?.y == level.bounds?.y
        && meta.bounds?.width == level.bounds?.width
        && meta.bounds?.height == level.bounds?.height, "bounds")
    check(meta.backgroundDecals.count == level.backgroundDecals.count, "backgroundDecals count")
    check(meta.decals.count == level.decals.count, "decals count")
    check(decodedEntities.count == sourceEntities.count, "entity count")
    for (a, b) in zip(decodedEntities, sourceEntities) {
      // Entity has no Equatable conformance; compare the reflected fields.
      let am = Mirror(reflecting: a).children
      let bm = Mirror(reflecting: b).children
      for (ac, bc) in zip(am, bm) {
        let equal: Bool
        switch (ac.value, bc.value) {
        case (let x as Int32, let y as Int32): equal = x == y
        case (let x as Bool, let y as Bool): equal = x == y
        case (let x as EntityType, let y as EntityType): equal = x == y
        default: equal = false
        }
        if !equal {
          check(false, "entity id \(a.id) field \(ac.label ?? "?")")
        }
      }
    }
  }
  return failures
}

guard failures == 0 else {
  FileHandle.standardError.write(Data("error: \(failures) round-trip mismatches\n".utf8))
  exit(1)
}

try Data(blob).write(to: URL(fileURLWithPath: outputPath))
print("levels.bin: \(levels.count) levels, \(blob.count) bytes (\(String(format: "%.1f", Double(blob.count) / 1024))KB), round-trip OK")
