// Junkbot for the Nintendo Wii, written in Embedded Swift against libogc/GX
// (https://github.com/MillerTechnologyPeru/swift-embedded-wii).
//
// This is a minimal scaffold, not a full port: it builds a single small hardcoded level directly
// through GameEngine's beginLoadLevel/add*/finishLoadLevel API (see buildLevel() below) and draws
// every entity as a flat-colored GX quad instead of a real sprite atlas. Its purpose is to prove
// the whole pipeline end to end - JunkbotCore compiling and running under Embedded Swift for
// powerpc-none-none-eabi, a GX rendering loop, and Wii Remote IR-pointer input driving
// GameEngine's mouseDown/mouseMove/mouseUp - before investing in a real texture-based renderer
// and an asset pipeline (SD card or embedded) for the full level catalog.
//
// LevelCatalog.swift (file-system level discovery) and Level.init(text:) in LevelParse.swift
// (already gated `#if !hasFeature(Embedded)` upstream - `.lowercased()` pulls in Unicode tables
// that don't link under Embedded Swift) both need capabilities this target doesn't have, so this
// level is built by hand instead of parsed from `levels/*.txt`. See ../Makefile, which compiles
// this file together with the rest of JunkbotCore's sources (minus LevelCatalog.swift) as one
// whole-module build - there's no SwiftPM here, so JunkbotCore can't be `import`ed as a prebuilt
// module the way every other port does.

typealias MtxRow = (Float, Float, Float, Float)

private let FIFO_SIZE: UInt32 = 256 * 1024

private var frameBuffer: UnsafeMutableRawPointer!
private var readyForCopy: UInt8 = 0

// Post-retrace callback: copies the EFB to the external framebuffer once a frame has been drawn.
// A C function pointer, so it may only touch globals (same pattern as the swift-embedded-wii
// triangle example).
private let copyBuffers: @convention(c) (UInt32) -> Void = { _ in
  if readyForCopy == UInt8(kGX_TRUE) {
    GX_SetZMode(UInt8(kGX_FALSE), UInt8(kGX_ALWAYS), UInt8(kGX_TRUE))
    GX_SetColorUpdate(UInt8(kGX_TRUE))
    GX_CopyDisp(frameBuffer, UInt8(kGX_TRUE))
    GX_Flush()
    readyForCopy = 0
  }
}

// MARK: - Level

/// Builds this scaffold's one hardcoded puzzle directly through `GameEngine`'s incremental
/// level-building API (no text parsing - see the file-level doc comment). Junkbot starts on the
/// left of a floor with a bin at the right end; a two-row-tall wall (bricks are always exactly
/// one grid row tall, so a 2-row obstacle needs two stacked bricks - see `EntityFactory.swift`)
/// blocks the path and is too tall for Junkbot to climb automatically (confirmed against this
/// exact layout with a native, non-Embedded build of JunkbotCore before writing this file: left
/// alone, Junkbot never reaches the bin; dragging both wall bricks out of the way lets him
/// through to a win), so reaching the bin requires dragging both bricks aside with the Wii
/// Remote pointer.
func buildLevel(_ engine: GameEngine) {
  engine.initialize()
  engine.beginLoadLevel(0, 0, 240, 200)
  engine.addBrick(0, 144, 8, 0, true)
  engine.addBrick(120, 144, 4, 0, true)
  engine.addJunkbot(0, 72, 1, false)
  engine.addBin(150, 90, 1, false)
  engine.addBrick(90, 126, 2, 1, false)
  engine.addBrick(90, 108, 2, 1, false)
  engine.finishLoadLevel()
}

/// Flat fill color for one entity - the scaffold's stand-in for the real sprite atlas
/// (`Generated/SpriteTable.swift`, unused here).
private func fillColor(for entity: Entity) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
  switch entity.type {
  case .junkbot: return (255, 196, 0, 255)
  case .bin: return (64, 200, 64, 255)
  case .brick:
    if entity.fixed { return (140, 140, 140, 255) }
    switch entity.colorIndex {
    case 0: return (235, 235, 235, 255)
    case 1: return (220, 40, 40, 255)
    case 2: return (40, 180, 40, 255)
    case 3: return (40, 100, 220, 255)
    case 4: return (230, 200, 40, 255)
    default: return (140, 140, 140, 255)
    }
  default: return (200, 200, 200, 255)
  }
}

// MARK: - Rendering

private func drawQuad(x: Float, y: Float, width: Float, height: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
  GX_Begin(UInt8(kGX_QUADS), UInt8(kGX_VTXFMT0), 4)
  GX_Position3f32(x, y, 0)
  GX_Color4u8(r, g, b, a)
  GX_Position3f32(x + width, y, 0)
  GX_Color4u8(r, g, b, a)
  GX_Position3f32(x + width, y + height, 0)
  GX_Color4u8(r, g, b, a)
  GX_Position3f32(x, y + height, 0)
  GX_Color4u8(r, g, b, a)
  GX_End()
}

@_cdecl("main")
func main() -> CInt {
  VIDEO_Init()
  WPAD_Init()

  let screenMode = VIDEO_GetPreferredMode(nil)!
  frameBuffer = wii_mem_k0_to_k1(SYS_AllocateFramebuffer(screenMode))

  VIDEO_Configure(screenMode)
  VIDEO_SetNextFramebuffer(frameBuffer)
  VIDEO_SetPostRetraceCallback(copyBuffers)
  VIDEO_SetBlack(false)
  VIDEO_Flush()
  VIDEO_WaitVSync()
  if (screenMode.pointee.viTVMode & kVI_NON_INTERLACE) != 0 {
    VIDEO_WaitVSync()
  }

  // Wii Remote pointer: report IR in screen-pixel space (matches fbWidth/efbHeight below) so it
  // maps onto world-space rendering with a single divide (see `worldScale` below).
  _ = WPAD_SetDataFormat(0, kWPAD_FMT_BTNS_ACC_IR)
  WPAD_SetVRes(0, UInt32(screenMode.pointee.fbWidth), UInt32(screenMode.pointee.efbHeight))

  let fifo = wii_mem_k0_to_k1(memalign(32, Int(FIFO_SIZE)))
  memset(fifo, 0, Int(FIFO_SIZE))
  GX_Init(fifo, FIFO_SIZE)
  GX_SetCopyClear(GXColor(r: 20, g: 20, b: 40, a: 255), 0x00FF_FFFF)

  let fbWidth = Float(screenMode.pointee.fbWidth)
  let efbHeight = Float(screenMode.pointee.efbHeight)
  GX_SetViewport(0, 0, fbWidth, efbHeight, 0, 1)
  _ = GX_SetDispCopyYScale(Float(screenMode.pointee.xfbHeight) / efbHeight)
  GX_SetScissor(0, 0, UInt32(screenMode.pointee.fbWidth), UInt32(screenMode.pointee.efbHeight))
  GX_SetDispCopySrc(0, 0, screenMode.pointee.fbWidth, screenMode.pointee.efbHeight)
  GX_SetDispCopyDst(screenMode.pointee.fbWidth, screenMode.pointee.xfbHeight)
  wii_set_copy_filter(screenMode)
  GX_SetFieldMode(
    screenMode.pointee.field_rendering,
    (screenMode.pointee.viHeight == 2 * screenMode.pointee.xfbHeight) ? UInt8(kGX_ENABLE) : UInt8(kGX_DISABLE))

  GX_SetCullMode(UInt8(kGX_CULL_NONE))
  GX_CopyDisp(frameBuffer, UInt8(kGX_TRUE))
  GX_SetDispCopyGamma(UInt8(kGX_GM_1_0))
  GX_SetZMode(UInt8(kGX_FALSE), UInt8(kGX_ALWAYS), UInt8(kGX_TRUE))

  // World-space (game pixels) <-> screen-space orthographic projection. `worldScale` magnifies
  // the level (its own coordinates only span ~240x200 game-pixels) to fill more of the TV.
  let worldScale: Float = 2
  let projection = UnsafeMutablePointer<MtxRow>.allocate(capacity: 4)  // Mtx44
  guOrtho(projection, 0, efbHeight / worldScale, 0, fbWidth / worldScale, 0, 1)
  GX_LoadProjectionMtx(projection, UInt8(kGX_ORTHOGRAPHIC))

  let modelView = UnsafeMutablePointer<MtxRow>.allocate(capacity: 3)  // Mtx
  c_guMtxIdentity(modelView)
  GX_LoadPosMtxImm(modelView, UInt32(kGX_PNMTX0))

  GX_ClearVtxDesc()
  GX_SetVtxDesc(UInt8(kGX_VA_POS), UInt8(kGX_DIRECT))
  GX_SetVtxDesc(UInt8(kGX_VA_CLR0), UInt8(kGX_DIRECT))
  GX_SetVtxAttrFmt(UInt8(kGX_VTXFMT0), UInt32(kGX_VA_POS), UInt32(kGX_POS_XYZ), UInt32(kGX_F32), 0)
  GX_SetVtxAttrFmt(UInt8(kGX_VTXFMT0), UInt32(kGX_VA_CLR0), UInt32(kGX_CLR_RGBA), UInt32(kGX_RGBA8), 0)
  GX_SetNumChans(1)
  GX_SetNumTexGens(0)
  GX_SetTevOrder(UInt8(kGX_TEVSTAGE0), UInt8(kGX_TEXCOORDNULL), UInt32(kGX_TEXMAP_NULL), UInt8(kGX_COLOR0A0))
  GX_SetTevOp(UInt8(kGX_TEVSTAGE0), UInt8(kGX_PASSCLR))

  let gameEngine = GameEngine()
  buildLevel(gameEngine)

  // Wii Remote pointer state, in world-space game pixels.
  var pointerWorldX: Float = 0
  var pointerWorldY: Float = 0
  var pointerValid = false
  var isDragging = false

  // JunkbotCore simulates at a fixed 18 ticks/second (`SIM_TICKS_PER_SECOND`); the display
  // refreshes at ~50/60Hz, so tick every third frame rather than pulling in a wall-clock API for
  // this scaffold.
  var frameCounter: UInt32 = 0

  while SYS_MainLoop() {
    WPAD_ScanPads()

    let held = WPAD_ButtonsHeld(0)
    let pressed = WPAD_ButtonsDown(0)
    let released = WPAD_ButtonsUp(0)

    if (held & kWPAD_BUTTON_HOME) != 0 {
      break
    }

    if let data = WPAD_Data(0), data.pointee.data_present != 0 {
      let ir = data.pointee.ir
      pointerValid = ir.valid != 0
      if pointerValid {
        pointerWorldX = ir.x / worldScale
        pointerWorldY = ir.y / worldScale
      }
    } else {
      pointerValid = false
    }

    if pointerValid {
      let worldX = Int32(pointerWorldX)
      let worldY = Int32(pointerWorldY)
      if (pressed & kWPAD_BUTTON_A) != 0 {
        gameEngine.mouseDown(worldX, worldY)
      } else if (released & kWPAD_BUTTON_A) != 0 {
        gameEngine.mouseUp(worldX, worldY)
      } else {
        gameEngine.mouseMove(worldX, worldY)
      }
      isDragging = gameEngine.isDragging
    }

    frameCounter += 1
    if frameCounter % 3 == 0 {
      gameEngine.tick()
    }

    GX_InvVtxCache()
    for entity in gameEngine.entities {
      let fill = fillColor(for: entity)
      drawQuad(
        x: Float(entity.x), y: Float(entity.y),
        width: Float(entity.width), height: Float(entity.height),
        r: fill.r, g: fill.g, b: fill.b, a: fill.a)
    }
    if pointerValid {
      let cursor: (r: UInt8, g: UInt8, b: UInt8, a: UInt8) =
        isDragging ? (255, 240, 0, 255) : (255, 255, 255, 255)
      drawQuad(
        x: pointerWorldX - 4, y: pointerWorldY - 4, width: 8, height: 8,
        r: cursor.r, g: cursor.g, b: cursor.b, a: cursor.a)
    }

    GX_DrawDone()
    readyForCopy = UInt8(kGX_TRUE)
    VIDEO_WaitVSync()
  }

  WPAD_Shutdown()
  return 0
}
