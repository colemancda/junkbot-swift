// Level loading helpers — JS parses level text and calls these Swift exports
// to build the entity list. JS then calls finishLoadLevel() to start the game.

func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
    levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
    // Center viewport on level
    viewportCenterX = x + width / 2
    viewportCenterY = y + height / 2
}

// Convenience — add any entity produced by JS-side parsing
func addEntityToLevel(_ entity: Entity) {
    var e = entity
    if e.id == 0 { e.id = getID() }
    entities.append(e)
}
