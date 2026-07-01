extension GameEngine {

  func makeBrick(x: Int32, y: Int32, widthInStuds: Int32, colorIndex: Int32, fixed: Bool) -> Entity
  {
    var e = Entity(
      id: getID(), type: .brick, x: x, y: y,
      width: widthInStuds * CELL_W, height: CELL_H)
    e.widthInStuds = widthInStuds
    e.colorIndex = colorIndex
    e.fixed = fixed
    return e
  }

  func makeJunkbot(x: Int32, y: Int32, facing: Int32, armored: Bool = false) -> Entity {
    var e = Entity(
      id: getID(), type: .junkbot, x: x, y: y,
      width: 2 * CELL_W, height: 4 * CELL_H)
    e.facing = facing
    e.armored = armored
    return e
  }

  func makeGearbot(x: Int32, y: Int32, facing: Int32) -> Entity {
    var e = Entity(
      id: getID(), type: .gearbot, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
    e.facing = facing
    return e
  }

  func makeClimbbot(x: Int32, y: Int32, facing: Int32, facingY: Int32 = 0) -> Entity {
    var e = Entity(
      id: getID(), type: .climbbot, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
    e.facing = facing
    e.facingY = facingY
    return e
  }

  func makeFlybot(x: Int32, y: Int32, facing: Int32) -> Entity {
    var e = Entity(
      id: getID(), type: .flybot, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
    e.facing = facing
    return e
  }

  func makeEyebot(x: Int32, y: Int32, facing: Int32 = 1, facingY: Int32 = 0) -> Entity {
    var e = Entity(
      id: getID(), type: .eyebot, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
    e.facing = facing
    e.facingY = facingY
    return e
  }

  func makeBin(x: Int32, y: Int32, facing: Int32 = 0, scaredy: Bool = false) -> Entity {
    var e = Entity(
      id: getID(), type: .bin, x: x, y: y,
      width: 2 * CELL_W, height: 3 * CELL_H)
    e.facing = facing
    e.scaredy = scaredy
    return e
  }

  func makeCrate(x: Int32, y: Int32) -> Entity {
    Entity(
      id: getID(), type: .crate, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
  }

  func makeFire(x: Int32, y: Int32, on: Bool, switchID: Int32 = -1) -> Entity {
    var e = Entity(
      id: getID(), type: .fire, x: x, y: y,
      width: CELL_W, height: CELL_H)
    e.on = on
    e.switchID = switchID
    e.fixed = true
    return e
  }

  func makeFan(x: Int32, y: Int32, on: Bool, switchID: Int32 = -1) -> Entity {
    var e = Entity(
      id: getID(), type: .fan, x: x, y: y,
      width: 4 * CELL_W, height: 2 * CELL_H)
    e.on = on
    e.switchID = switchID
    e.fixed = true
    return e
  }

  func makeSwitch(x: Int32, y: Int32, on: Bool, switchID: Int32 = -1) -> Entity {
    var e = Entity(
      id: getID(), type: .switch, x: x, y: y,
      width: 2 * CELL_W, height: CELL_H)
    e.on = on
    e.switchID = switchID
    e.fixed = true
    return e
  }

  func makeTeleport(x: Int32, y: Int32, teleportID: Int32 = -1) -> Entity {
    var e = Entity(
      id: getID(), type: .teleport, x: x, y: y,
      width: 4 * CELL_W, height: 2 * CELL_H)
    e.teleportID = teleportID
    e.fixed = true
    return e
  }

  func makeLaser(x: Int32, y: Int32, facing: Int32, on: Bool, switchID: Int32 = -1) -> Entity {
    var e = Entity(
      id: getID(), type: .laser, x: x, y: y,
      width: 2 * CELL_W, height: CELL_H)
    e.facing = facing
    e.on = on
    e.switchID = switchID
    e.fixed = true
    return e
  }

  func makeJump(x: Int32, y: Int32, fixed: Bool = true) -> Entity {
    var e = Entity(
      id: getID(), type: .jump, x: x, y: y,
      width: 2 * CELL_W, height: CELL_H)
    e.fixed = fixed
    return e
  }

  func makeShield(x: Int32, y: Int32, used: Bool = false, fixed: Bool = true) -> Entity {
    var e = Entity(
      id: getID(), type: .shield, x: x, y: y,
      width: 2 * CELL_W, height: CELL_H)
    e.used = used
    e.fixed = fixed
    return e
  }

  func makePipe(x: Int32, y: Int32) -> Entity {
    var e = Entity(
      id: getID(), type: .pipe, x: x, y: y,
      width: 2 * CELL_W, height: 2 * CELL_H)
    e.fixed = true
    e.timer = randomInt(MAX_DRIP_PERIOD - MIN_DRIP_PERIOD) + MIN_DRIP_PERIOD
    return e
  }

  func makeDroplet(x: Int32, y: Int32) -> Entity {
    Entity(
      id: getID(), type: .droplet, x: x, y: y,
      width: CELL_W, height: CELL_H)
  }
}
