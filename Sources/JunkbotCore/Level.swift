extension GameEngine {

    func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
        levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
        viewportCenterX = x + width / 2
        viewportCenterY = y + height / 2
    }
}
