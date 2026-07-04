import JavaScriptKit
import JunkbotCore

/// Transport for `RenderFrame`s to JS: a persistent, capacity-doubling buffer in WASM linear
/// memory (NOT a Swift `Array`, whose storage pointer can move between calls). JS reads it via
/// `new Int32Array(instance.exports.memory.buffer)`, re-viewed on every call since the memory
/// can grow. Header: `[totalCount, backgroundCount, placeable, reserved]`, then `totalCount`
/// stride-8 `Int32` records: `[kind, spriteID, x, y, a, b, c, reserved]`.
final class RenderCommandBuffer {
    private static let headerStride = 4
    private static let recordStride = 8

    private var buffer: UnsafeMutablePointer<Int32>
    private var capacityRecords: Int

    init(initialCapacityRecords: Int = 512) {
        capacityRecords = initialCapacityRecords
        buffer = .allocate(capacity: Self.headerStride + capacityRecords * Self.recordStride)
    }

    deinit {
        buffer.deallocate()
    }

    /// Writes `frame` into the buffer (growing it first if needed) and returns the buffer's base
    /// address as an `Int32` (WASM pointers are 32-bit) for JS to index into its `Int32Array`
    /// view of the module's exported memory.
    func write(_ frame: RenderFrame) -> Int32 {
        if frame.commands.count > capacityRecords {
            capacityRecords = max(frame.commands.count, capacityRecords * 2)
            buffer.deallocate()
            buffer = .allocate(capacity: Self.headerStride + capacityRecords * Self.recordStride)
        }
        buffer[0] = Int32(frame.commands.count)
        buffer[1] = Int32(frame.backgroundCount)
        buffer[2] = frame.placeable ? 1 : 0
        buffer[3] = 0
        var offset = Self.headerStride
        for command in frame.commands {
            buffer[offset] = command.kind.rawValue
            buffer[offset + 1] = command.spriteID
            buffer[offset + 2] = command.x
            buffer[offset + 3] = command.y
            buffer[offset + 4] = command.a
            buffer[offset + 5] = command.b
            buffer[offset + 6] = command.c
            buffer[offset + 7] = 0
            offset += Self.recordStride
        }
        return Int32(Int(bitPattern: UnsafeRawPointer(buffer)))
    }
}

/// One buffer per export (renderWorld/renderEntityList/renderPreviewEntity may all be called
/// within the same JS render pass — e.g. the editor's palette-preview buttons are drawn on their
/// own canvases right after the main renderWorld call — so each needs its own storage rather
/// than clobbering a shared one before JS has read it).
let renderWorldBuffer = RenderCommandBuffer()
let renderEntityListBuffer = RenderCommandBuffer(initialCapacityRecords: 64)
let renderPreviewBuffer = RenderCommandBuffer(initialCapacityRecords: 16)

/// One-time (startup) transport for the sprite name table, built entirely from raw UTF-8 bytes
/// copied out of `spriteNameTable`'s `StaticString`s — deliberately avoiding any Swift
/// `String`/`JSString` construction from dynamic content, which this embedded-WASM target has no
/// established path for (every existing JS-bound string in `main.swift` is a compile-time
/// `JSString` literal, e.g. `let dropletType: JSString = "droplet"` — never built from bytes/an
/// arbitrary `StaticString` at runtime). JS decodes names itself via `TextDecoder`.
///
/// Layout: `recordCount` Int32, then `recordCount` records of
/// `[sheet, width, height, nameByteOffset, nameByteLength]` (5 Int32 words each), then a raw
/// UTF-8 byte blob holding every name back-to-back (empty names - unused gap slots in a
/// non-contiguous frame family - get length 0).
final class SpriteTableByteBuffer {
    let base: UnsafeMutableRawPointer
    let totalBytes: Int

    init() {
        let recordStride = 5 * MemoryLayout<Int32>.stride
        let headerBytes = MemoryLayout<Int32>.stride
        let recordsBytes = spriteNameTable.count * recordStride

        var nameBytes: [UInt8] = []
        var offsets: [(Int32, Int32)] = []  // (offset, length) per sprite ID
        offsets.reserveCapacity(spriteNameTable.count)
        for name in spriteNameTable {
            let start = Int32(nameBytes.count)
            name.withUTF8Buffer { nameBytes.append(contentsOf: $0) }
            offsets.append((start, Int32(nameBytes.count) - start))
        }

        totalBytes = headerBytes + recordsBytes + nameBytes.count
        base = .allocate(byteCount: totalBytes, alignment: MemoryLayout<Int32>.alignment)

        let words = base.bindMemory(to: Int32.self, capacity: (headerBytes + recordsBytes) / 4)
        words[0] = Int32(spriteNameTable.count)
        var w = 1
        for id in 0..<spriteNameTable.count {
            words[w] = spriteSheetTable[id]
            words[w + 1] = spriteWidthTable[id]
            words[w + 2] = spriteHeightTable[id]
            words[w + 3] = offsets[id].0
            words[w + 4] = offsets[id].1
            w += 5
        }

        let nameRegion = (base + headerBytes + recordsBytes).bindMemory(
            to: UInt8.self, capacity: nameBytes.count)
        for i in 0..<nameBytes.count {
            nameRegion[i] = nameBytes[i]
        }
    }

    deinit {
        base.deallocate()
    }
}
let spriteTableByteBuffer = SpriteTableByteBuffer()

/// Reused across calls to avoid per-call allocation (mirrors `var renderFrame` in JunkbotSDL3).
var wasmRenderFrame = RenderFrame()

extension GameEngine {

    /// `renderSpriteTable() -> ptr`, called once at JS startup so it can build its own
    /// name -> {image, atlas frame} lookup from its already-loaded spritesheets, keyed by the
    /// same sprite IDs this engine emits. See `SpriteTableByteBuffer` for the layout JS decodes.
    func renderSpriteTableExport(_ args: [JSValue]) -> JSValue {
        Int32(Int(bitPattern: UnsafeRawPointer(spriteTableByteBuffer.base))).jsValue
    }

    /// `engineSetBackground(backdropSpriteID, bgDecalsFlat, decalsFlat)`: decal arrays are flat
    /// `[x, y, spriteID, ...]` number arrays with names already resolved to IDs by the JS host
    /// (avoids Swift-side String comparisons for level-load-time data — see `renderWorldExport`'s
    /// doc comment on why per-frame code stays string-free; this is a one-time-per-load cost
    /// either way, but keeping the resolution JS-side means this engine never needs the sprite
    /// *name* tables at runtime, only the ID/sheet/size ones).
    func engineSetBackgroundExport(_ args: [JSValue]) -> JSValue {
        let backdropSpriteID = Int32(args[0].number ?? -1)
        setBackground(
            backdropSpriteID: backdropSpriteID,
            backgroundDecals: decodeFlatDecals(args[1]),
            decals: decodeFlatDecals(args[2]))
        return .undefined
    }

    private func decodeFlatDecals(_ value: JSValue) -> [DecalInstance] {
        guard let array = value.object else { return [] }
        let length = Int(array.length.number ?? 0)
        var result: [DecalInstance] = []
        result.reserveCapacity(length / 3)
        var i = 0
        while i + 2 < length {
            result.append(
                DecalInstance(
                    x: Int32(array[i].number ?? 0), y: Int32(array[i + 1].number ?? 0),
                    spriteID: Int32(array[i + 2].number ?? -1)))
            i += 3
        }
        return result
    }

    /// `renderWorld(editing, jsEntitiesOrNull) -> ptr`. While editing, the JS entities mirror is
    /// authoritative (this engine's own `entities` can be stale for editor-only mutations like
    /// delete/flip/paste — see `mergeGrabbedEntities`'s doc comment), so the caller passes its
    /// live array and this converts it via the existing `engineEntity(from:)` bridge; otherwise
    /// renders from `entities` directly.
    func renderWorldExport(_ args: [JSValue]) -> JSValue {
        let editing = args[0].boolean ?? false
        var overrideEntities: [Entity]? = nil
        if editing, let jsEntities = args[1].object {
            let length = Int(jsEntities.length.number ?? 0)
            var converted: [Entity] = []
            converted.reserveCapacity(length)
            for i in 0..<length {
                guard let object = jsEntities[i].object else { continue }
                converted.append(engineEntity(from: object))
            }
            overrideEntities = converted
        }
        buildRenderFrame(into: &wasmRenderFrame, editing: editing, entitiesOverride: overrideEntities)
        return renderWorldBuffer.write(wasmRenderFrame).jsValue
    }

    /// `renderEntityList(jsEntities) -> ptr` — the playback ghost overlay.
    func renderEntityListExport(_ args: [JSValue]) -> JSValue {
        guard let jsEntities = args[0].object else { return (-1).jsValue }
        let length = Int(jsEntities.length.number ?? 0)
        var converted: [Entity] = []
        converted.reserveCapacity(length)
        for i in 0..<length {
            guard let object = jsEntities[i].object else { continue }
            converted.append(engineEntity(from: object))
        }
        let commands = buildEntityListCommands(converted)
        var frame = RenderFrame()
        frame.commands = commands
        frame.backgroundCount = 0
        frame.placeable = true
        return renderEntityListBuffer.write(frame).jsValue
    }

    /// `renderPreviewEntity(jsEntity) -> ptr` — one editor palette button.
    func renderPreviewEntityExport(_ args: [JSValue]) -> JSValue {
        guard let object = args[0].object else { return (-1).jsValue }
        let entity = engineEntity(from: object)
        let commands = buildPreviewCommands(for: entity, editing: true)
        var frame = RenderFrame()
        frame.commands = commands
        frame.backgroundCount = 0
        frame.placeable = true
        return renderPreviewBuffer.write(frame).jsValue
    }
}
