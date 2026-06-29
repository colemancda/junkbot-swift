// Game simulation — faithful port of the JS simulation logic

// MARK: - Win / Lose

func winOrLose() -> Int32 {
    let hasBins = entities.contains(where: { $0.type == .bin && !$0.removeBeforeRender })
    let hasJunkbot = entities.contains(where: { $0.type == .junkbot })
    if !hasBins { return 1 } // win: all bins collected
    if !hasJunkbot { return 2 } // lose: junkbot gone
    let junkbotDead = entities.first(where: { $0.type == .junkbot })?.dead == true
    if junkbotDead { return 2 }
    return 0
}

// MARK: - Hurt Junkbot

func hurtJunkbot(index: Int, cause: Int32) {
    // cause: 0=bot, 1=fire, 2=water, 3=laser
    var junkbot = entities[index]
    if junkbot.dying || junkbot.dead || junkbot.grabbed { return }
    if !junkbot.losingShield {
        switch cause {
        case 1: playSound(.deathByFire)
        case 2: playSound(.deathByWater)
        case 3: playSound(.deathByLaser)
        default: playSound(.deathByBot)
        }
    }
    if junkbot.armored {
        if !junkbot.losingShield {
            junkbot.losingShield = true
        }
    } else {
        junkbot.animationFrame = 0
        junkbot.collectingBin = false
        junkbot.dying = true
        if cause == 2 { junkbot.dyingFromWater = true }
    }
    entities[index] = junkbot
}

// MARK: - Gravity

func simulateGravity() {
    for i in 0..<entities.count {
        let e = entities[i]
        guard !e.fixed && !e.grabbed && !e.floating &&
              e.type != .droplet && e.type != .junkbot &&
              e.type != .climbbot && e.type != .flybot && e.type != .eyebot
        else { continue }

        let notSettled =
            rectangleLevelBoundsCollision(x: e.x, y: e.y + 1, width: e.width, height: e.height) == nil &&
            !connectsToFixed(startIndex: i, direction: (e.type == .gearbot || e.type == .crate || e.type == .bin) ? 1 : 0)

        if notSettled {
            if entityCollisionTest(entityX: e.x, entityY: e.y, entityIndex: i, filter: isNotDroplet) != nil {
                continue // stuck in wall
            }
            let cellDownY = e.y + CELL_H
            let hits = entityCollisionAll(entityX: e.x, entityY: cellDownY + 1, entityIndex: i, filter: isNotDroplet)
            if let ground = hits.min(by: { $0.entity.y < $1.entity.y }) {
                entities[i].y = ground.entity.y - e.height
            } else {
                entities[i].y = cellDownY
            }
            entityMoved(index: i)
        }
    }
}

// MARK: - Walk (Junkbot)

// Returns true if turned around
@discardableResult
func walk(junkbotIndex: Int) -> Bool {
    let junkbot = entities[junkbotIndex]
    let posInFrontX = junkbot.x + junkbot.facing * CELL_W
    let posInFrontY = junkbot.y

    let stepOrWall = entityCollisionTest(
        entityX: posInFrontX, entityY: posInFrontY, entityIndex: junkbotIndex,
        filter: isNotBinOrDropletOrEnemyBot)

    if let wall = stepOrWall {
        // Can we step up?
        let posStepUpY = wall.y - junkbot.height
        if posStepUpY - junkbot.y >= -CELL_H && posStepUpY - junkbot.y < 0 &&
           entityCollisionTest(entityX: posInFrontX, entityY: posStepUpY, entityIndex: junkbotIndex,
                               filter: isNotBinOrDroplet) == nil {
            entities[junkbotIndex].x = posInFrontX
            entities[junkbotIndex].y = posStepUpY
            entityMoved(index: junkbotIndex)
            return false
        }
    }

    // Is there solid ground ahead to walk on?
    let ground = entityCollisionTest(
        entityX: posInFrontX, entityY: posInFrontY + 1, entityIndex: junkbotIndex,
        filter: isNotBinOrDropletOrEnemyBot)

    if ground != nil &&
       entityCollisionTest(entityX: posInFrontX, entityY: posInFrontY, entityIndex: junkbotIndex,
                           filter: isNotBinOrDroplet) == nil {
        entities[junkbotIndex].x = posInFrontX
        entities[junkbotIndex].y = posInFrontY
        entityMoved(index: junkbotIndex)
        return false
    }

    // Can we step down?
    let stepsBelow = entityCollisionAll(
        entityX: posInFrontX, entityY: posInFrontY + CELL_H + 1, entityIndex: junkbotIndex,
        filter: isNotBinOrDropletOrEnemyBot)
    if let stepDown = stepsBelow.min(by: { $0.entity.y < $1.entity.y }) {
        let posStepDownY = stepDown.entity.y - junkbot.height
        if posStepDownY - junkbot.y <= CELL_H && posStepDownY - junkbot.y > 0 &&
           entityCollisionTest(entityX: posInFrontX, entityY: posStepDownY, entityIndex: junkbotIndex,
                               filter: isNotBinOrDroplet) == nil {
            entities[junkbotIndex].x = posInFrontX
            entities[junkbotIndex].y = posStepDownY
            entityMoved(index: junkbotIndex)
            return false
        }
    }

    // Turn around
    entities[junkbotIndex].facing *= -1
    playSound(.turn)
    return true
}

// MARK: - Find linked teleport index

func findLinkedTeleportIndex(for teleportIndex: Int) -> Int {
    let tp = entities[teleportIndex]
    for i in 0..<entities.count {
        if i == teleportIndex { continue }
        let other = entities[i]
        if other.type == .teleport && other.teleportID == tp.teleportID {
            return i
        }
    }
    return -1
}

// MARK: - Simulate Junkbot

func simulateJunkbot(index: Int) {
    var junkbot = entities[index]

    // Check head loaded
    let aboveHead = entityCollisionTest(
        entityX: junkbot.x, entityY: junkbot.y - 1, entityIndex: index,
        filter: isNotDroplet)
    var headLoaded = false
    if let ah = aboveHead {
        headLoaded = junkbot.floating || (
            !ah.fixed &&
            !connectsToFixed(startIndex: entities.firstIndex(where: { $0.id == ah.id }) ?? 0,
                             ignoreIndices: [index]) &&
            ah.type != .levelBounds && ah.type != .flybot && ah.type != .eyebot
        )
    }
    if junkbot.headLoaded && !headLoaded {
        junkbot.headLoaded = false
    } else if headLoaded && !junkbot.headLoaded && !junkbot.grabbed {
        junkbot.headLoaded = true
        playSound(.headBonk)
    }

    // Shield loss timer
    if junkbot.losingShield {
        junkbot.losingShieldTime += 1
        if junkbot.losingShieldTime > 36 {
            junkbot.armored = false
            junkbot.losingShield = false
            junkbot.losingShieldTime = 0
            playSound(.losePowerup)
        }
    }

    junkbot.animationFrame += 1

    // Collecting bin animation
    if junkbot.collectingBin {
        if junkbot.animationFrame >= 17 {
            junkbot.collectingBin = false
            junkbot.animationFrame = 0
        } else {
            entities[index] = junkbot
            return
        }
    }

    // Dying animation
    if junkbot.dying {
        if junkbot.animationFrame >= 10 {
            junkbot.animationFrame = 0
            junkbot.dead = true
        }
        entities[index] = junkbot
        return
    }

    if junkbot.dead {
        entities[index] = junkbot
        return
    }

    // Getting shield animation
    if junkbot.gettingShield {
        if junkbot.animationFrame >= 11 {
            junkbot.gettingShield = false
            junkbot.armored = true
        } else {
            entities[index] = junkbot
            return
        }
    }

    // Stuck in wall check
    if entityCollisionTest(entityX: junkbot.x, entityY: junkbot.y, entityIndex: index,
                           filter: isNotDroplet) != nil {
        entities[index] = junkbot
        return
    }

    // Floating (carried by fan)
    if junkbot.floating {
        let abovePos = (x: junkbot.x, y: junkbot.y - CELL_H)
        if entityCollisionTest(entityX: abovePos.x, entityY: abovePos.y, entityIndex: index,
                               filter: isNotDroplet) == nil {
            junkbot.x = abovePos.x
            junkbot.y = abovePos.y
            entityMoved(index: index)
        }
        entities[index] = junkbot
        return
    }

    // Ballistic motion (airborne or jumping)
    let inAir = entityCollisionTest(entityX: junkbot.x, entityY: junkbot.y + 1, entityIndex: index,
                                    filter: isNotDroplet) == nil
    let unaligned = junkbot.x % CELL_W != 0
    let jumpStarting = junkbot.momentumY < -2

    if inAir || jumpStarting || unaligned {
        let dirX: Int32 = junkbot.momentumY < -2 ? 0 : (junkbot.momentumX > 0 ? 1 : (junkbot.momentumX < 0 ? -1 : 0))
        let dirY: Int32 = junkbot.momentumY > 0 ? 1 : (junkbot.momentumY < 0 ? -1 : 0)
        let newX = junkbot.x + dirX * CELL_W
        let newY = junkbot.y + dirY * CELL_H
        let collideXY = entityCollisionTest(entityX: newX, entityY: newY, entityIndex: index,
                                            filter: isNotDroplet) != nil
        if collideXY {
            let collideYOnly = entityCollisionTest(entityX: junkbot.x, entityY: newY,
                                                   entityIndex: index, filter: isNotDroplet) == nil
            let collideXOnly = entityCollisionTest(entityX: newX, entityY: junkbot.y,
                                                   entityIndex: index, filter: isNotDroplet) == nil
            if collideYOnly {
                junkbot.momentumX = 0
                junkbot.y = newY
            } else if collideXOnly {
                junkbot.momentumY = 0
                junkbot.x = newX
            } else {
                junkbot.momentumX = 0
                junkbot.momentumY = 0
            }
            playSound(.headBonk)
        } else {
            junkbot.x = newX
            junkbot.y = newY
            junkbot.momentumX -= Int32(dirX)
        }
        junkbot.momentumX = max(-5, min(5, junkbot.momentumX))
        junkbot.momentumY += 1
        junkbot.momentumY = max(-5, min(5, junkbot.momentumY))
        if junkbot.momentumY == 5 { playSound(.fall) }

        // Jump brick landing
        let jumpBrick = entityCollisionTest(
            entityX: junkbot.x, entityY: junkbot.y + 1, entityIndex: index,
            filter: { $0.type == .jump })
        let junkbotWidth = junkbot.width
        if let jb = jumpBrick, jb.x <= junkbot.x && jb.x + jb.width >= junkbot.x + junkbotWidth {
            let aheadBlocked = entityCollisionTest(
                entityX: junkbot.x + junkbot.facing * CELL_W, entityY: junkbot.y,
                entityIndex: index, filter: isNotDroplet) != nil
            if !aheadBlocked {
                if let jbIdx = entities.firstIndex(where: { $0.id == jb.id }), !entities[jbIdx].active {
                    junkbot.animationFrame = 0
                    junkbot.momentumY = -3
                    junkbot.momentumX = junkbot.facing * 5
                    playSound(.jump)
                    entities[jbIdx].active = true
                    entities[jbIdx].animationFrame = 0
                }
            }
        }
        entityMoved(index: index)
        entities[index] = junkbot
        return
    }

    // Walking step every 5 frames
    if junkbot.animationFrame % 5 == 4 {
        // Push crates
        let posInFrontX = junkbot.x + junkbot.facing * CELL_W
        let cratesInFront = rectangleCollisionAll(
            x: posInFrontX, y: junkbot.y, width: junkbot.width, height: junkbot.height + 1,
            filter: { $0.type == .crate && ($0.x + $0.width <= junkbot.x || junkbot.x + junkbot.width <= $0.x) })
        let canPushCrates = cratesInFront.allSatisfy { crate in
            entityCollisionTest(
                entityX: crate.entity.x + junkbot.facing * CELL_W,
                entityY: crate.entity.y,
                entityIndex: crate.index,
                filter: isNotDroplet) == nil
        }
        if canPushCrates {
            for crate in cratesInFront {
                entities[crate.index].x += junkbot.facing * CELL_W
            }
        }

        let turnedAround = walk(junkbotIndex: index)
        junkbot = entities[index] // re-read after walk modifies it

        // Ground level entity interactions
        let groundY = junkbot.y + junkbot.height
        for i in 0..<entities.count {
            let ground = entities[i]
            guard ground.y == groundY else { continue }
            guard ground.x <= junkbot.x && ground.x + ground.width >= junkbot.x + junkbot.width else { continue }
            if !turnedAround {
                switch ground.type {
                case .switch:
                    entities[i].on = !entities[i].on
                    let swID = ground.switchID
                    if swID >= 0 {
                        for j in 0..<entities.count {
                            if entities[j].type != .switch && entities[j].switchID == swID {
                                entities[j].on = !entities[j].on
                            }
                        }
                    }
                    playSound(.switchClick)
                    playSound(entities[i].on ? .switchOn : .switchOff)
                case .fire where ground.on:
                    hurtJunkbot(index: index, cause: 1)
                    junkbot = entities[index]
                case .shield where !ground.used && (junkbot.losingShield || !junkbot.armored):
                    junkbot.animationFrame = 0
                    junkbot.gettingShield = true
                    junkbot.losingShield = false
                    junkbot.losingShieldTime = 0
                    entities[i].used = true
                    playSound(.getShield)
                    playSound(.getPowerup)
                case .jump where !ground.active:
                    junkbot.animationFrame = 0
                    junkbot.momentumY = -3
                    junkbot.momentumX = junkbot.facing * 5
                    playSound(.jump)
                    entities[i].active = true
                    entities[i].animationFrame = 0
                case .teleport where ground.timer == 0 && junkbot.x == ground.x + CELL_W:
                    let linkedIdx = findLinkedTeleportIndex(for: i)
                    if linkedIdx >= 0 && !entities[linkedIdx].blocked {
                        junkbot.x = entities[linkedIdx].x + CELL_W
                        junkbot.y = entities[linkedIdx].y - junkbot.height
                        entities[i].timer = TELEPORT_COOLDOWN
                        entities[linkedIdx].timer = TELEPORT_COOLDOWN
                        entityMoved(index: index)
                        playSound(.teleportSound)
                    }
                default: break
                }
            }
        }

        // Collect bin
        let binAhead = entityCollisionTest(
            entityX: junkbot.x + junkbot.facing * CELL_W, entityY: junkbot.y,
            entityIndex: index, filter: { $0.type == .bin })
        if let bin = binAhead, let binIdx = entities.firstIndex(where: { $0.id == bin.id }) {
            junkbot.animationFrame = 0
            junkbot.collectingBin = true
            entities[binIdx].removeBeforeRender = true
            playSound(.collectBin)
            playSound(.collectBin2)
        }
    }

    entities[index] = junkbot
}

// MARK: - Simulate Gearbot

func simulateGearbot(index: Int) {
    entities[index].animationFrame += 1
    if entities[index].animationFrame > 2 {
        entities[index].animationFrame = 0
        let gearbot = entities[index]
        let aheadX = gearbot.x + gearbot.facing * CELL_W
        let ahead = entityCollisionTest(
            entityX: aheadX, entityY: gearbot.y, entityIndex: index,
            filter: isNotDroplet)
        let groundAheadX = gearbot.facing == -1 ? gearbot.x - CELL_W : gearbot.x + gearbot.width
        let groundAhead = rectangleCollisionTest(
            x: groundAheadX, y: gearbot.y + 1, width: CELL_W, height: gearbot.height,
            filter: isNotDroplet)
        if let a = ahead {
            if a.type == .junkbot, let jIdx = entities.firstIndex(where: { $0.id == a.id }),
               !entities[jIdx].dying && !entities[jIdx].dead {
                hurtJunkbot(index: jIdx, cause: 0)
            }
            entities[index].facing *= -1
        } else if groundAhead != nil {
            entities[index].x = aheadX
            entityMoved(index: index)
        } else {
            entities[index].facing *= -1
        }
    }
}

// MARK: - Simulate Climbbot

func simulateClimbbot(index: Int) {
    entities[index].animationFrame += 1
    if entities[index].animationFrame > 6 {
        entities[index].animationFrame = 0
        let c = entities[index]
        let asideX = c.x + c.facing * CELL_W
        let aheadPos = c.facingY == 0
            ? (x: asideX, y: c.y)
            : (x: c.x, y: c.y + c.facingY * CELL_H)
        let belowPos = (x: c.x, y: c.y + CELL_H)
        let behindX = c.x + c.facing * -CELL_W

        let aside = entityCollisionTest(entityX: asideX, entityY: c.y, entityIndex: index,
                                        filter: isNotDroplet)
        let groundAside = entityCollisionTest(entityX: asideX, entityY: c.y + 1, entityIndex: index,
                                              filter: isNotBinOrDroplet)
        let ahead = entityCollisionTest(entityX: aheadPos.x, entityY: aheadPos.y,
                                        entityIndex: index, filter: isNotDroplet)
        let behindHoriz = entityCollisionTest(entityX: behindX, entityY: c.y, entityIndex: index,
                                              filter: isNotDroplet)
        let below = entityCollisionTest(entityX: belowPos.x, entityY: belowPos.y,
                                        entityIndex: index, filter: isNotDroplet)

        if let a = ahead, a.type == .junkbot, let jIdx = entities.firstIndex(where: { $0.id == a.id }) {
            hurtJunkbot(index: jIdx, cause: 0)
        }

        if c.facingY == -1 {
            if aside == nil && groundAside != nil {
                entities[index].facingY = 0
                entities[index].x = asideX
                entityMoved(index: index)
            } else if entities[index].energy > 0 && ahead == nil {
                entities[index].energy -= 1
                entities[index].x = aheadPos.x
                entities[index].y = aheadPos.y
                entityMoved(index: index)
            } else {
                entities[index].facingY = 1
            }
        } else if c.facingY == 1 {
            if below != nil {
                if aside != nil && behindHoriz != nil {
                    entities[index].facingY = -1
                    entities[index].energy = 3
                } else {
                    entities[index].facingY = 0
                    if aside != nil {
                        if behindHoriz == nil {
                            entities[index].facing *= -1
                            entities[index].x = behindX
                            entityMoved(index: index)
                        }
                    } else {
                        entities[index].x = asideX
                        entityMoved(index: index)
                    }
                }
            } else {
                entities[index].x = belowPos.x
                entities[index].y = belowPos.y
                entityMoved(index: index)
            }
        } else {
            if below != nil {
                if aside != nil {
                    entities[index].facingY = -1
                    entities[index].energy = 3
                } else {
                    entities[index].x = asideX
                    entityMoved(index: index)
                }
            } else {
                if aside != nil {
                    entities[index].facingY = 1
                } else {
                    entities[index].facingY = 1
                    entities[index].x = belowPos.x
                    entities[index].y = belowPos.y
                    entityMoved(index: index)
                }
            }
        }
        if entities[index].facingY != -1 { entities[index].energy = 0 }
    }
}

// MARK: - Simulate Flybot

func simulateFlybot(index: Int) {
    entities[index].animationFrame += 1
    if entities[index].animationFrame % 2 == 0 {
        let f = entities[index]
        let aheadX = f.x + f.facing * CELL_W
        let ahead = entityCollisionTest(entityX: aheadX, entityY: f.y,
                                        entityIndex: index,
                                        filter: { $0.type != .droplet })
        if let a = ahead {
            if a.type == .junkbot, let jIdx = entities.firstIndex(where: { $0.id == a.id }) {
                hurtJunkbot(index: jIdx, cause: 0)
            }
            entities[index].facing *= -1
        } else {
            entities[index].x = aheadX
            entityMoved(index: index)
        }
    }
}

// MARK: - Simulate Eyebot

func doEyebotTargeting(index: Int) {
    let eyebot = entities[index]
    let offsets: [(Int32, Int32)] = [(0, 0), (CELL_W, 0), (0, CELL_H), (CELL_W, CELL_H)]
    let directions: [(Int32, Int32)] = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    for (dirX, dirY) in directions {
        let rayOffsets: [(Int32, Int32)]
        if dirY != 0 { rayOffsets = [(0, 0), (CELL_W, 0)] }
        else         { rayOffsets = [(0, 0), (0, CELL_H)] }
        for (offX, offY) in rayOffsets {
            let hit = raycast(
                startX: eyebot.x + offX, startY: eyebot.y + offY,
                width: CELL_W, height: CELL_H,
                directionX: dirX, directionY: dirY,
                maxSteps: 50,
                filter: { $0.type != .droplet && $0.id != eyebot.id })
            if let entity = hit.entity, entity.type == .junkbot {
                entities[index].facing = dirX
                entities[index].facingY = dirY
                entities[index].activeTimer = 110
            }
        }
    }
    _ = offsets // suppress unused warning
}

func doEyebotMovement(index: Int) {
    entities[index].activeTimer -= 1
    entities[index].animationFrame += 1
    let e = entities[index]
    let period = e.activeTimer > 0 ? 1 : 2
    if e.animationFrame % Int32(period) == 0 {
        let aheadX = e.x + e.facing * CELL_W
        let aheadY = e.y + e.facingY * CELL_H
        let ahead = entityCollisionTest(
            entityX: aheadX, entityY: aheadY, entityIndex: index,
            filter: { $0.type != .droplet })
        if let a = ahead {
            if a.type == .junkbot, let jIdx = entities.firstIndex(where: { $0.id == a.id }) {
                hurtJunkbot(index: jIdx, cause: 0)
            }
            entities[index].facing *= -1
            entities[index].facingY *= -1
        } else {
            entities[index].x = aheadX
            entities[index].y = aheadY
            entityMoved(index: index)
        }
    }
}

// MARK: - Simulate Scaredy Bin

func simulateScaredy(index: Int) {
    entities[index].animationFrame += 1
    if entities[index].animationFrame > 2 {
        entities[index].animationFrame = 0
        let bin = entities[index]
        let searchDist: Int32 = CELL_W * 4
        let junkbotHit = rectangleCollisionTest(
            x: bin.x - searchDist, y: bin.y,
            width: bin.width + searchDist * 2, height: bin.height,
            filter: { $0.type == .junkbot })
        if let jb = junkbotHit {
            let newFacing: Int32 = jb.x > bin.x ? -1 : 1
            entities[index].facing = newFacing
            let aheadX = bin.x + newFacing * CELL_W
            let ahead = entityCollisionTest(entityX: aheadX, entityY: bin.y, entityIndex: index,
                                            filter: isNotDroplet)
            if ahead != nil {
                entities[index].facing = 0
            } else {
                entities[index].x = aheadX
                entityMoved(index: index)
            }
        } else {
            entities[index].facing = 0
        }
    }
}

// MARK: - Simulate Droplet

func simulateDroplet(index: Int) {
    if entities[index].splashing {
        entities[index].animationFrame += 1
        if entities[index].animationFrame > 4 {
            entities[index].removeBeforeRender = true
        }
    } else {
        let droplet = entities[index]
        for _ in 0..<18 {
            entities[index].y += 1
            entityMoved(index: index)
            let dy = entities[index].y
            let dx = droplet.x
            let dw = droplet.width
            for j in 0..<entities.count {
                if j == index { continue }
                let g = entities[j]
                if g.grabbed { continue }
                if g.type == .droplet { continue }
                let groundY = g.y
                if groundY != dy + droplet.height { continue }
                if dx + dw <= g.x || dx >= g.x + g.width { continue }
                if g.type == .junkbot {
                    hurtJunkbot(index: j, cause: 2)
                }
                entities[index].splashing = true
                entities[index].animationFrame = 0
                let drip = randomInt(3)
                switch drip {
                case 0: playSound(.drip0)
                case 1: playSound(.drip1)
                default: playSound(.drip2)
                }
                return
            }
        }
    }
}

// MARK: - Simulate Pipe

func simulatePipe(index: Int) {
    entities[index].timer -= 1
    if entities[index].timer == 0 {
        let pipe = entities[index]
        entities.append(makeDroplet(x: pipe.x, y: pipe.y))
    }
    if entities[index].timer <= 0 {
        entities[index].timer = randomInt(MAX_DRIP_PERIOD - MIN_DRIP_PERIOD) + MIN_DRIP_PERIOD
    }
}

// MARK: - Simulate Jump block

func simulateJump(index: Int) {
    entities[index].animationFrame += 1
    if entities[index].animationFrame >= 5 {
        entities[index].animationFrame = 0
        entities[index].active = false
    }
}

// MARK: - Simulate Teleport

func simulateTeleport(index: Int) {
    if entities[index].timer > 0 {
        entities[index].timer -= 1
    }
    let tp = entities[index]
    let linkedIdx = findLinkedTeleportIndex(for: index)
    if linkedIdx < 0 {
        entities[index].blocked = true
        return
    }
    let linked = entities[linkedIdx]
    let selfBlocked = rectangleCollisionTest(
        x: tp.x + CELL_W, y: tp.y - CELL_H * 4,
        width: CELL_W * 2, height: CELL_H * 4,
        filter: isNotDropletOrJunkbot) != nil
    let linkedBlocked = rectangleCollisionTest(
        x: linked.x + CELL_W, y: linked.y - CELL_H * 4,
        width: CELL_W * 2, height: CELL_H * 4,
        filter: isNotDropletOrJunkbot) != nil
    entities[index].blocked = selfBlocked || linkedBlocked

    if tp.timer > TELEPORT_COOLDOWN - TELEPORT_EFFECT_PERIOD {
        teleportEffects.append(TeleportEffect(
            x: tp.x + CELL_W,
            y: tp.y,
            frameIndex: tp.timer % 3))
    }
}

// MARK: - Fan / Laser pass

func simulateFansAndLasers() {
    wind.removeAll(keepingCapacity: true)
    laserBeams.removeAll(keepingCapacity: true)

    for i in 0..<entities.count {
        let e = entities[i]

        if e.type == .fan && e.on {
            var effect = WindEffect(fanEntityIndex: i)
            var x = e.x + CELL_W
            while x < e.x + e.width - CELL_W {
                var extent: Int32 = 0
                var y = e.y - CELL_H
                while y > -200 {
                    var collision = false
                    for j in 0..<entities.count {
                        let other = entities[j]
                        if other.grabbed { continue }
                        if !rectanglesIntersect(x, y, CELL_W, CELL_H, other.x, other.y, other.width, other.height) { continue }
                        if other.type == .junkbot {
                            if !other.wasFloating {
                                playSound(.fan)
                            }
                            entities[j].floating = true
                        } else if other.type != .droplet {
                            collision = true
                            break
                        }
                    }
                    if collision { break }
                    extent += 1
                    y -= CELL_H
                }
                effect.addExtent(extent)
                x += CELL_W
            }
            wind.append(effect)
        }

        if e.type == .laser && e.on {
            var extent: Int32 = 0
            var hitIdx = -1
            var running = true
            while running && extent < 200 {
                let lx = e.x + (e.facing == 1 ? e.width : -CELL_W) + CELL_W * extent * e.facing
                for j in 0..<entities.count {
                    let other = entities[j]
                    if other.grabbed { continue }
                    if !rectanglesIntersect(lx, e.y, CELL_W, CELL_H, other.x, other.y, other.width, other.height) { continue }
                    if other.type == .junkbot, let jIdx = entities.firstIndex(where: { $0.id == other.id }) {
                        hurtJunkbot(index: jIdx, cause: 3)
                    }
                    if other.type != .droplet {
                        hitIdx = j
                        running = false
                        break
                    }
                }
                if running { extent += 1 }
            }
            laserBeams.append(LaserBeam(laserEntityIndex: i, extent: extent, hitEntityIndex: hitIdx))
        }
    }
}

// MARK: - Main simulate step

func simulate() {
    frameCounter += 1

    rebuildAccelerationStructures()

    // Sort for gravity: process higher-y (lower on screen) entities first
    entities.sort { $0.y > $1.y }

    simulateGravity()

    teleportEffects.removeAll(keepingCapacity: true)

    for i in 0..<entities.count {
        let e = entities[i]
        if e.grabbed { continue }
        switch e.type {
        case .junkbot: simulateJunkbot(index: i)
        case .gearbot: simulateGearbot(index: i)
        case .climbbot: simulateClimbbot(index: i)
        case .flybot: simulateFlybot(index: i)
        case .eyebot: doEyebotMovement(index: i)
        case .jump: simulateJump(index: i)
        case .teleport: simulateTeleport(index: i)
        case .pipe: simulatePipe(index: i)
        case .droplet: simulateDroplet(index: i)
        case .bin where e.scaredy: simulateScaredy(index: i)
        default:
            if entities[i].animationFrame != -1 {
                entities[i].animationFrame += 1
            }
        }
    }

    // Remove flagged entities
    entities.removeAll(where: { $0.removeBeforeRender })

    // Eyebot targeting (separate pass)
    for i in 0..<entities.count {
        if entities[i].type == .eyebot { doEyebotTargeting(index: i) }
    }

    // Clear floating flag (will be reset by fan simulation each frame)
    for i in 0..<entities.count {
        entities[i].wasFloating = entities[i].floating
        entities[i].floating = false
    }

    simulateFansAndLasers()

    // Sort by ID for consistency
    entities.sort { $0.id < $1.id }

    // Check win/lose
    let newState = winOrLose()
    if newState != winLoseState {
        winLoseState = newState
        if newState == 1 {
            playSound(.ohYeah)
        } else if newState == 2 {
            playSound(.ouch)
        }
    }
}
