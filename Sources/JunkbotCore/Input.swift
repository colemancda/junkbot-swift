extension GameEngine {

    func possibleGrabsAt(worldX: Int32, worldY: Int32) -> [Int] {
        var result: [Int] = []
        for i in 0..<entities.count {
            let e = entities[i]
            if e.fixed { continue }
            if e.grabbed { continue }
            if e.type == .junkbot || e.type == .gearbot || e.type == .climbbot ||
               e.type == .flybot || e.type == .eyebot || e.type == .droplet { continue }
            if worldX >= e.x && worldX < e.x + e.width &&
               worldY >= e.y && worldY < e.y + e.height {
                result.append(i)
            }
        }
        return result
    }

    func attachedAbove(startIndex: Int) -> [Int] {
        var result: [Int] = []
        var frontier: [Int] = [startIndex]
        while !frontier.isEmpty {
            let current = frontier.removeLast()
            let e = entities[current]
            let topY = e.y
            for i in 0..<entities.count {
                if i == current { continue }
                if result.contains(i) || i == startIndex { continue }
                let other = entities[i]
                if other.fixed { continue }
                if other.type == .junkbot || other.type == .gearbot || other.type == .climbbot ||
                   other.type == .flybot || other.type == .eyebot || other.type == .droplet { continue }
                if other.y + other.height == topY &&
                   other.x + other.width > e.x && other.x < e.x + e.width {
                    result.append(i)
                    frontier.append(i)
                }
            }
        }
        return result
    }

    func startDrag(entityIndex: Int, worldX: Int32, worldY: Int32) {
        guard !entities[entityIndex].grabbed else { return }
        draggingIndices = [entityIndex] + attachedAbove(startIndex: entityIndex)
        moves += 1
        for idx in draggingIndices {
            entities[idx].grabbed = true
            entities[idx].grabOffsetX = entities[idx].x - worldX
            entities[idx].grabOffsetY = entities[idx].y - worldY
        }
        playSound(.blockPickUp)
    }

    func updateDrag(worldX: Int32, worldY: Int32) {
        guard !draggingIndices.isEmpty else { return }
        let baseIdx = draggingIndices[0]
        let snapWorldX = snapToGrid(worldX + entities[baseIdx].grabOffsetX, CELL_W)
        let snapWorldY = snapToGrid(worldY + entities[baseIdx].grabOffsetY, CELL_H)
        let dx = snapWorldX - entities[baseIdx].x
        let dy = snapWorldY - entities[baseIdx].y
        if dx != 0 || dy != 0 {
            for idx in draggingIndices {
                entities[idx].x += dx
                entities[idx].y += dy
            }
        }
    }

    func finishDrag() {
        guard !draggingIndices.isEmpty else { return }
        var canPlace = true
        for idx in draggingIndices {
            let e = entities[idx]
            if entityCollisionTest(entityX: e.x, entityY: e.y, entityIndex: idx, filter: { other in
                !other.grabbed && other.type != .droplet
            }) != nil {
                canPlace = false
                break
            }
        }
        for idx in draggingIndices {
            entities[idx].grabbed = false
            entityMoved(index: idx)
        }
        playSound(canPlace ? .blockDrop : .blockClick)
        draggingIndices.removeAll(keepingCapacity: true)
    }

    func snapToGrid(_ value: Int32, _ grid: Int32) -> Int32 {
        let r = value % grid
        if r == 0 { return value }
        if r < grid / 2 { return value - r }
        return value - r + grid
    }
}
