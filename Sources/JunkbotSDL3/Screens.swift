import CSDL3
import CSDL3Image
import Foundation
import JunkbotCore

/// Which screen is currently active - the native equivalent of `src/game.js`'s
/// `location.hash`-driven `SCREEN_TITLE`/`SCREEN_LEVEL_SELECT`/`SCREEN_LEVEL` routing, minus all
/// URL/hash/slug logic (a native app has no address bar to keep in sync - see the Phase 6 plan's
/// "Established facts" for why that's out of scope, not just deferred). `.title` and `.playing`
/// both tick/render the gameplay world (the title screen is itself a normal playable level with
/// draggable bricks, per `src/game.js`'s `showTitleScreen`); the others show static menu UI only.
enum Screen: Equatable {
  case title
  case levelSelect(game: LevelCatalog.Game, page: Int)
  case playing
  case levelWinDialog
  case levelLoseDialog
}

@MainActor var currentScreen: Screen = .title
@MainActor var currentGame: LevelCatalog.Game = .junkbot
@MainActor var currentLevelEntry: LevelCatalogEntry?
/// Rebuilt whenever `currentScreen` changes; hit-tested by the main loop's mouse-down handler
/// when not `.playing`/`.title` (world-space drag input owns those instead).
@MainActor var menuButtons: [Button] = []

let titleScreenLevelURL = repoRoot.appendingPathComponent("levels/custom/Title Screen.txt")

/// `SaveData` lives at the macOS-conventional Application Support location (not repo-relative,
/// unlike every other asset path here - this is real user data, not a dev-time repo asset).
let saveDataURL: URL = {
  let base =
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ?? URL(fileURLWithPath: NSHomeDirectory())
  return base.appendingPathComponent("Junkbot", isDirectory: true)
    .appendingPathComponent("save.json")
}()

func loadSaveData() -> SaveData {
  guard let data = try? Data(contentsOf: saveDataURL),
    let decoded = try? JSONDecoder().decode(SaveData.self, from: data)
  else { return SaveData() }
  return decoded
}

@MainActor func writeSaveData() {
  do {
    try FileManager.default.createDirectory(
      at: saveDataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(saveData)
    try data.write(to: saveDataURL)
  } catch {
    FileHandle.standardError.write(Data("Failed to write save data: \(error)\n".utf8))
  }
}

@MainActor var saveData = loadSaveData()

@MainActor func centerCameraOnLevel() {
  if let bounds = gameEngine.levelBounds {
    cameraCenterX = Double(bounds.x) + Double(bounds.width) / 2
    cameraCenterY = Double(bounds.y) + Double(bounds.height) / 2
  } else if !gameEngine.entities.isEmpty {
    let minX = gameEngine.entities.map(\.x).min() ?? 0
    let maxX = gameEngine.entities.map { $0.x + $0.width }.max() ?? 0
    let minY = gameEngine.entities.map(\.y).min() ?? 0
    let maxY = gameEngine.entities.map { $0.y + $0.height }.max() ?? 0
    cameraCenterX = Double(minX + maxX) / 2
    cameraCenterY = Double(minY + maxY) / 2
  }
}

@MainActor func loadLevel(_ entry: LevelCatalogEntry, game: LevelCatalog.Game) {
  guard let text = readLevelText(at: entry.url) else {
    FileHandle.standardError.write(Data("Failed to read \(entry.url.path)\n".utf8))
    return
  }
  currentLevelEntry = entry
  currentGame = game
  gameEngine.loadLevel(fromText: text)
  print("Level: \(entry.title)")
  musicPlayer.startRandomLevelMusic()
  centerCameraOnLevel()
}

// MARK: - Title screen

@MainActor func showTitleScreen() {
  currentScreen = .title
  guard let text = readLevelText(at: titleScreenLevelURL) else {
    FileHandle.standardError.write(Data("Failed to read \(titleScreenLevelURL.path)\n".utf8))
    return
  }
  gameEngine.loadLevel(fromText: text)
  centerCameraOnLevel()
  musicPlayer.startRandomLevelMusic()

  // Screen-space buttons, positioned relative to the window so they stay put across resizes.
  menuButtons = [
    Button(x: 20, y: 20, width: 90, height: 24, action: {
      showLevelSelectScreen(game: .junkbot, page: 0)
    }),
    Button(x: 120, y: 20, width: 140, height: 24, action: {
      showLevelSelectScreen(game: .junkbotUndercover, page: 0)
    }),
    Button(x: 20, y: 50, width: 90, height: 24, action: {
      _ = SDL_OpenURL("https://github.com/colemancda/junkbot-swift")
    }),
  ]
}

/// Draws the "Welcome to the factory..." overlay JS shows only on the level titled "Title
/// Screen" (`if (currentLevel.title === "Title Screen")` in `render()`), plus the three
/// screen-space buttons from `showTitleScreen()`. World-space coordinates here match JS's nested
/// `ctx.translate(-1, -25)` before `drawImage(panel, 41, 206)`/each text line - see the Phase 6
/// plan's "Established facts" for the derivation.
@MainActor func drawTitleScreenOverlay(offsetX: Float, offsetY: Float) {
  guard gameEngine.levelTitle == "Title Screen" else { return }

  if let panelTexture = titleScreenPanelTexture {
    var dst = SDL_FRect(x: Float(40) + offsetX, y: Float(181) + offsetY, w: 398, h: 86)
    _ = SDL_RenderTexture(renderer, panelTexture, nil, &dst)
  }

  let black = SDL_Color(r: 0, g: 0, b: 0, a: 255)
  let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
  let lines: [(String, SDL_Color, Int32, Int32)] = [
    ("Welcome to the factory", black, 114, 192),
    ("Try moving the colored bricks", white, 72, 210),
    ("with the mouse", white, 163, 228),
    ("before you play the game", black, 103, 246),
  ]
  for (text, color, x, y) in lines {
    textRenderer.draw(
      text, x: Int32(offsetX) + x, y: Int32(offsetY) + y, color: color, scale: 2)
  }

  textRenderer.draw("Play Junkbot", x: 28, y: 26, color: white)
  textRenderer.draw("Play Undercover", x: 128, y: 26, color: white)
  textRenderer.draw("Credits", x: 28, y: 56, color: white)
}

@MainActor let titleScreenPanelTexture: UnsafeMutablePointer<SDL_Texture>? = {
  let url = repoRoot.appendingPathComponent("images/menus/loading_bkg_frame.png")
  guard let surface = IMG_Load(url.path) else { return nil }
  defer { SDL_DestroySurface(surface) }
  guard let texture = SDL_CreateTextureFromSurface(renderer, surface) else { return nil }
  _ = SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)
  return texture
}()

// MARK: - Level select

let levelSelectRowHeight: Float = 22
let levelSelectRowsTop: Float = 90

@MainActor func showLevelSelectScreen(game: LevelCatalog.Game, page: Int) {
  currentScreen = .levelSelect(game: game, page: page)
  currentGame = game
  gameEngine.setPaused(true)

  let pageCount = levelCatalog.pagesByGame[game]?.count ?? 0
  var buttons: [Button] = [
    Button(x: 20, y: 20, width: 90, height: 24, action: { showTitleScreen() })
  ]
  for tabIndex in 0..<pageCount {
    buttons.append(
      Button(x: Float(130 + tabIndex * 70), y: 20, width: 60, height: 24, action: {
        showLevelSelectScreen(game: game, page: tabIndex)
      }))
  }
  let entries = levelCatalog.pagesByGame[game]?[safe: page] ?? []
  for (rowIndex, entry) in entries.enumerated() {
    buttons.append(
      Button(
        x: 40, y: levelSelectRowsTop + Float(rowIndex) * levelSelectRowHeight,
        width: 600, height: levelSelectRowHeight,
        action: {
          loadLevel(entry, game: game)
          currentScreen = .playing
        }))
  }
  menuButtons = buttons
}

@MainActor func drawLevelSelectScreen(game: LevelCatalog.Game, page: Int) {
  _ = SDL_SetRenderDrawColor(renderer, 60, 60, 65, 255)
  _ = SDL_RenderClear(renderer)

  let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
  let gold = SDL_Color(r: 220, g: 180, b: 40, a: 255)
  textRenderer.draw("Back", x: 28, y: 26, color: white)

  let pages = levelCatalog.pagesByGame[game] ?? []
  for (tabIndex, _) in pages.enumerated() {
    let color = tabIndex == page ? gold : white
    textRenderer.draw("Page \(tabIndex + 1)", x: Int32(130 + tabIndex * 70) + 4, y: 26, color: color)
  }

  guard let entries = pages[safe: page] else { return }
  for (rowIndex, entry) in entries.enumerated() {
    let y = Int32(levelSelectRowsTop) + Int32(rowIndex) * Int32(levelSelectRowHeight) + 4
    let completed = saveData.isCompleted(levelTitle: entry.title)
    let gold_ = saveData.isGold(levelTitle: entry.title, par: entry.par)
    var label = "\(page * 15 + rowIndex + 1). \(entry.title)"
    if let moves = saveData.bestMoves[entry.title] {
      label += " (\(moves) moves)"
    }
    textRenderer.draw(label, x: 44, y: y, color: gold_ ? gold : (completed ? white : white))
  }
}

// MARK: - Win / lose dialogs

@MainActor func showLevelWinDialog() {
  currentScreen = .levelWinDialog
  guard let entry = currentLevelEntry else { return }
  saveData.recordWin(levelTitle: entry.title, moves: Int(gameEngine.moves))
  writeSaveData()

  var buttons: [Button] = [
    Button(x: 200, y: 300, width: 140, height: 28, action: {
      guard let (page, _) = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
      else { showTitleScreen(); return }
      showLevelSelectScreen(game: currentGame, page: page)
    })
  ]
  if let next = levelCatalog.nextLevel(after: entry.title, game: currentGame) {
    buttons.append(
      Button(x: 360, y: 300, width: 140, height: 28, action: {
        loadLevel(next, game: currentGame)
        currentScreen = .playing
      }))
  }
  menuButtons = buttons
}

@MainActor func showLevelLoseDialog() {
  currentScreen = .levelLoseDialog
  guard let entry = currentLevelEntry else { return }
  menuButtons = [
    Button(x: 200, y: 300, width: 140, height: 28, action: {
      guard let (page, _) = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
      else { showTitleScreen(); return }
      showLevelSelectScreen(game: currentGame, page: page)
    }),
    Button(x: 360, y: 300, width: 140, height: 28, action: {
      loadLevel(entry, game: currentGame)
      currentScreen = .playing
    }),
  ]
}

let loseMessages = [
  "I knew that was going to happen.",
  "I hate mondays.",
  "Why me?",
]

@MainActor func drawDialogOverlay() {
  var overlay = SDL_FRect(x: 0, y: 0, w: Float(windowWidth), h: Float(windowHeight))
  _ = SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
  _ = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 160)
  _ = SDL_RenderFillRect(renderer, &overlay)

  let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
  switch currentScreen {
  case .levelWinDialog:
    textRenderer.draw("Level Complete!", x: 220, y: 240, color: white, scale: 2)
    textRenderer.draw("Select Level", x: 216, y: 308, color: white)
    if levelCatalog.nextLevel(after: currentLevelEntry?.title ?? "", game: currentGame) != nil {
      textRenderer.draw("Next Level", x: 386, y: 308, color: white)
    }
  case .levelLoseDialog:
    textRenderer.draw(loseMessages.randomElement() ?? "", x: 200, y: 240, color: white, scale: 2)
    textRenderer.draw("Select Level", x: 216, y: 308, color: white)
    textRenderer.draw("Retry", x: 386, y: 308, color: white)
  default:
    break
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
