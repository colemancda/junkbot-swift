// JavaScript imports — provided by the WASM host (harness.js).
// All names become WebAssembly imports from the "env" module.

// --- Canvas / rendering ---

@_extern(c, "js_begin_frame")
func jsBeginFrame()

@_extern(c, "js_end_frame")
func jsEndFrame()

@_extern(c, "js_clear_background")
func jsClearBackground()

@_extern(c, "js_set_viewport")
func jsSetViewport(_ centerX: Int32, _ centerY: Int32, _ scale: Float)

@_extern(c, "js_draw_brick")
func jsDrawBrick(_ x: Int32, _ y: Int32, _ colorIndex: Int32, _ widthInStuds: Int32, _ fixed: Int32)

@_extern(c, "js_draw_junkbot")
// flags: bit0=armored, bit1=dying, bit2=dyingFromWater, bit3=collectingBin,
//        bit4=floating, bit5=losingShield, bit6=gettingShield
func jsDrawJunkbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ animFrame: Int32, _ flags: Int32)

@_extern(c, "js_draw_gearbot")
func jsDrawGearbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_climbbot")
func jsDrawClimbbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_flybot")
func jsDrawFlybot(_ x: Int32, _ y: Int32, _ facing: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_eyebot")
func jsDrawEyebot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32, _ animFrame: Int32, _ laserOn: Int32)

@_extern(c, "js_draw_bin")
func jsDrawBin(_ x: Int32, _ y: Int32, _ facing: Int32, _ scaredy: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_crate")
func jsDrawCrate(_ x: Int32, _ y: Int32)

@_extern(c, "js_draw_fire")
func jsDrawFire(_ x: Int32, _ y: Int32, _ on: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_fan")
func jsDrawFan(_ x: Int32, _ y: Int32, _ on: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_switch")
func jsDrawSwitch(_ x: Int32, _ y: Int32, _ on: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_pipe")
func jsDrawPipe(_ x: Int32, _ y: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_shield")
func jsDrawShield(_ x: Int32, _ y: Int32, _ used: Int32, _ fixed: Int32)

@_extern(c, "js_draw_jump")
func jsDrawJump(_ x: Int32, _ y: Int32, _ active: Int32, _ animFrame: Int32, _ fixed: Int32)

@_extern(c, "js_draw_teleport")
func jsDrawTeleport(_ x: Int32, _ y: Int32, _ animFrame: Int32, _ blocked: Int32)

@_extern(c, "js_draw_laser")
func jsDrawLaser(_ x: Int32, _ y: Int32, _ facing: Int32, _ on: Int32)

@_extern(c, "js_draw_droplet")
func jsDrawDroplet(_ x: Int32, _ y: Int32, _ splashing: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_wind_column")
func jsDrawWindColumn(_ x: Int32, _ y: Int32, _ extent: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_laser_beam")
func jsDrawLaserBeam(_ x: Int32, _ y: Int32, _ facing: Int32, _ extent: Int32, _ hitWall: Int32, _ animFrame: Int32)

@_extern(c, "js_draw_teleport_effect")
func jsDrawTeleportEffect(_ x: Int32, _ y: Int32, _ frameIndex: Int32)

@_extern(c, "js_draw_debug_rect")
func jsDrawDebugRect(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32)

// Notify JS of win/lose
@_extern(c, "js_on_win")
func jsOnWin()

@_extern(c, "js_on_lose")
func jsOnLose()

// --- Audio ---

@_extern(c, "js_play_sound")
func jsPlaySound(_ soundIndex: Int32)

func playSound(_ sound: SoundID) {
    jsPlaySound(sound.rawValue)
}
