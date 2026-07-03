import CSDL3
import CSDL3Image
import Foundation
import JunkbotCore

/// Which screen is currently active - the native equivalent of `src/game.js`'s
/// `location.hash`-driven `SCREEN_TITLE`/`SCREEN_LEVEL_SELECT`/`SCREEN_LEVEL` routing, minus all
/// URL/hash/slug logic (a native app has no address bar to keep in sync). `.title` and `.playing`
/// both tick/render the gameplay world (the title screen is itself a normal playable level with
/// draggable bricks, per `src/game.js`'s `showTitleScreen`); the others show static menu UI only.
///
/// Visual/behavioral details are reconstructed from the original Director sources where the
/// HTML5 remake matches them: `screens_by_peter/behavior_screen_loop.ls` (level-select tabs at
/// blend 100 selected / 50 unselected, 21px rows with checkbox + gold-check + right-aligned
/// moves, rollover row highlight), `behavior_ListRoHiLite.ls` (row hit = (mouseV - top) / 21),
/// `behavior_msgBox_Title.ls` (the "LEVEL N: TITLE" toast, ~2s hold, click to dismiss),
/// `behavior_msgBox_Success.ls`/`_Fail.ls` (win/lose dialog contents incl. the "beat this level
/// in N moves or fewer" gold hint and the random fail messages), and
/// `behavior_level end dialog buttons behavior.ls` (h_button1 on press). Locking/keycards are
/// deliberately NOT reproduced - the HTML5 remake (the parity target) never implemented them.
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
/// (before world drag input, since menu buttons sit visually on top of the world).
@MainActor var menuButtons: [Button] = []
/// Last mouse position in *screen* space (window pixels), tracked on every screen (unlike
/// `lastMouseWorldX/Y`, which only updates on world-input screens) - drives the level-select
/// row rollover highlight, mirroring `behavior_ListRoHiLite.ls`'s `mouseWithin`.
@MainActor var lastMouseScreenX: Float = -1
@MainActor var lastMouseScreenY: Float = -1

let titleScreenLevelURL = repoRoot.appendingPathComponent("levels/custom/Title Screen.txt")

// MARK: - Save data

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

// MARK: - Menu image cache

/// Lazily-loaded `images/menus/*.png` textures, keyed by filename stem - the menu screens'
/// equivalent of the sprite `TextureCache` (which is keyed by generated sprite ID and scans the
/// sprite/background directories, neither of which covers `images/menus/`).
@MainActor var menuTextures: [String: UnsafeMutablePointer<SDL_Texture>] = [:]
@MainActor func menuTexture(_ name: String) -> UnsafeMutablePointer<SDL_Texture>? {
  if let cached = menuTextures[name] { return cached }
  let url = repoRoot.appendingPathComponent("images/menus/\(name).png")
  guard let surface = IMG_Load(url.path) else { return nil }
  defer { SDL_DestroySurface(surface) }
  guard let texture = SDL_CreateTextureFromSurface(renderer, surface) else { return nil }
  _ = SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)
  menuTextures[name] = texture
  return texture
}

@MainActor func drawMenuTexture(
  _ name: String, x: Float, y: Float, alphaPercent: Int32 = 100
) {
  guard let texture = menuTexture(name) else { return }
  var w: Float = 0
  var h: Float = 0
  _ = SDL_GetTextureSize(texture, &w, &h)
  if alphaPercent < 100 {
    _ = SDL_SetTextureAlphaMod(texture, UInt8(max(0, min(100, alphaPercent)) * 255 / 100))
  }
  var dst = SDL_FRect(x: x, y: y, w: w, h: h)
  _ = SDL_RenderTexture(renderer, texture, nil, &dst)
  if alphaPercent < 100 {
    _ = SDL_SetTextureAlphaMod(texture, 255)
  }
}

// MARK: - Level loading + title toast

/// While non-nil, the "LEVEL N: TITLE" toast is showing and the engine stays paused - the
/// native `behavior_msgBox_Title.ls` / HTML5 level-info-toast equivalent (Lingo holds ~2s and
/// dismisses on click; HTML5 holds 2.5s - matching HTML5, the parity target, with Lingo's
/// click-to-dismiss kept since it's strictly nicer and HTML5's toast is also click-through).
@MainActor var levelToastUntil: UInt64?
let levelToastNanoseconds: UInt64 = 2_500_000_000

@MainActor func dismissLevelToast() {
  guard levelToastUntil != nil else { return }
  levelToastUntil = nil
  gameEngine.setPaused(false)
}

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
  soundBoard.play(MenuSoundID.enterLevel)
  musicPlayer.startRandomLevelMusic()
  centerCameraOnLevel()
  // Every call site immediately sets currentScreen = .playing after this - clearing here once
  // (rather than at each call site) guarantees the previous screen's buttons (level rows,
  // win/lose dialog buttons) can never survive into gameplay and eat clicks meant for bricks.
  menuButtons = []
  // Show the "LEVEL N: TITLE" toast, paused, like both originals.
  gameEngine.setPaused(true)
  levelToastUntil = SDL_GetTicksNS() + levelToastNanoseconds
}

/// Draws the level-entry toast (building icon + "LEVEL N: TITLE"), centered near the top -
/// `behavior_msgBox_Title.ls`'s panel, simplified to the parts we have assets for.
@MainActor func drawLevelToast() {
  guard levelToastUntil != nil, let entry = currentLevelEntry else { return }
  let location = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
  let levelNumber = location.map { $0.page * 15 + $0.indexInPage + 1 } ?? 0

  let panelW: Float = 360
  let panelH: Float = 84
  let panelX = (Float(windowWidth) - panelW) / 2
  let panelY: Float = 60
  drawPanel(x: panelX, y: panelY, w: panelW, h: panelH)

  if currentGame == .junkbot, let page = location?.page {
    drawMenuTexture("building_icon_\(page + 1)", x: panelX + 12, y: panelY + 12)
    drawMenuTexture("building_text_\(page + 1)", x: panelX + 84, y: panelY + 18)
  } else if let page = location?.page {
    textRenderer.draw(
      "Basement \(page + 1)", x: Int32(panelX) + 16, y: Int32(panelY) + 20,
      color: SDL_Color(r: 255, g: 255, b: 255, a: 255), scale: 2)
  }
  textRenderer.draw(
    "Level \(levelNumber): \(entry.title)", x: Int32(panelX) + 16, y: Int32(panelY) + 58,
    color: SDL_Color(r: 255, g: 255, b: 255, a: 255), scale: 2)
}

// MARK: - Shared menu drawing

/// A simple beveled panel, standing in for the original's bitmap dialog frames (whose exact
/// frame art isn't among the preserved menu images).
@MainActor func drawPanel(x: Float, y: Float, w: Float, h: Float) {
  _ = SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
  var shadow = SDL_FRect(x: x + 4, y: y + 4, w: w, h: h)
  _ = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 120)
  _ = SDL_RenderFillRect(renderer, &shadow)
  var body = SDL_FRect(x: x, y: y, w: w, h: h)
  _ = SDL_SetRenderDrawColor(renderer, 168, 168, 168, 255)
  _ = SDL_RenderFillRect(renderer, &body)
  var border = body
  _ = SDL_SetRenderDrawColor(renderer, 60, 60, 60, 255)
  _ = SDL_RenderRect(renderer, &border)
}

/// Draws a `Button` as a raised rect with a centered label (the original swaps to `*_ro` member
/// art on rollover; a brightness change is the equivalent affordance with the assets we have).
@MainActor func drawButton(_ button: Button, label: String) {
  let hovered = button.contains(lastMouseScreenX, lastMouseScreenY)
  var body = SDL_FRect(x: button.x, y: button.y, w: button.width, h: button.height)
  _ = SDL_SetRenderDrawColor(
    renderer, hovered ? 220 : 190, hovered ? 220 : 190, hovered ? 200 : 170, 255)
  _ = SDL_RenderFillRect(renderer, &body)
  _ = SDL_SetRenderDrawColor(renderer, 40, 40, 40, 255)
  _ = SDL_RenderRect(renderer, &body)
  let size = textRenderer.measure(label)
  textRenderer.draw(
    label,
    x: Int32(button.x + (button.width - Float(size.width)) / 2),
    y: Int32(button.y + (button.height - Float(size.height)) / 2),
    color: SDL_Color(r: 0, g: 0, b: 0, a: 255))
}

/// Menu sound IDs, disjoint from `Types.swift`'s engine `SoundID` range (0-27) - played through
/// the same `SoundBoard`. Names/files match `src/game.js`'s `hotResourcePaths`/`otherResourcePaths`
/// (`buttonClick`/`tabSwitch`/`enterLevel`), themselves matching the Lingo sources' `SndSFX`
/// calls (`h_button1` in the dialog-button behavior, `h_powerup3` in `tabClicked`).
enum MenuSoundID {
  static let buttonClick: Int32 = 100
  static let tabSwitch: Int32 = 101
  static let enterLevel: Int32 = 102
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

  menuButtons = [
    Button(x: 16, y: 16, width: 120, height: 24, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      showLevelSelectScreen(game: .junkbot, page: 0)
    }),
    Button(x: 148, y: 16, width: 140, height: 24, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      showLevelSelectScreen(game: .junkbotUndercover, page: 0)
    }),
    Button(x: 16, y: 48, width: 120, height: 24, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      _ = SDL_OpenURL("https://github.com/colemancda/junkbot-swift")
    }),
  ]
}

/// Draws the "Welcome to the factory..." overlay JS shows only on the level titled "Title
/// Screen" (`if (currentLevel.title === "Title Screen")` in `render()`), plus this screen's
/// buttons. World-space panel/text coordinates match JS's `ctx.translate(-1, -25)` +
/// `drawImage(panel, 41, 206)` / the four `drawText` lines.
@MainActor func drawTitleScreenOverlay(offsetX: Float, offsetY: Float) {
  guard gameEngine.levelTitle == "Title Screen" else { return }

  drawMenuTexture("loading_bkg_frame", x: 40 + offsetX, y: 181 + offsetY)

  let black = SDL_Color(r: 0, g: 0, b: 0, a: 255)
  let white = SDL_Color(r: 255, g: 255, b: 255, a: 255)
  let lines: [(String, SDL_Color, Int32, Int32)] = [
    ("Welcome to the factory", black, 114, 192),
    ("Try moving the colored bricks", white, 72, 210),
    ("with the mouse", white, 163, 228),
    ("before you play the game", black, 103, 246),
  ]
  for (text, color, x, y) in lines {
    textRenderer.draw(text, x: Int32(offsetX) + x, y: Int32(offsetY) + y, color: color, scale: 2)
  }

  drawButton(menuButtons[0], label: "Play Junkbot")
  drawButton(menuButtons[1], label: "Play Undercover")
  drawButton(menuButtons[2], label: "Credits")
}

// MARK: - Level select

/// Layout replicating `index.html`'s `#level-select-screen` CSS (the HTML5 build's level select
/// is pure DOM/CSS, not canvas - these constants are its measured values): a 74px tab strip
/// (`#33CCFF` sky over a 32px `#33CC33` grass band) with overlapping `custom/tab.png` tabs
/// (124px wide, -15px margin), then the `#808080` list panel on a `#7c857c` page background,
/// 21px bold rows (20px + 1px `#CCCCCC` separator) with ordinal/checkbox/gold/title/score
/// columns at the CSS's own offsets (2/35/48/63/right), hover `#BFC0BF`.
let tabStripHeight: Float = 74
let tabImageWidth: Float = 124
let tabOverlap: Float = 15
let listPadX: Float = 11
// The CSS uses 13px list padding and 21px rows, but 15 of those plus the below-list Main button
// (which HTML5 places bottom-left, after the list) don't fit the title-screen-sized window -
// tightened proportionally so the whole layout, button included, matches the browser's.
let listPadY: Float = 5
let levelSelectRowHeight: Float = 18
let levelSelectRowsTop: Float = tabStripHeight + listPadY
let levelSelectRowsLeft: Float = 11

@MainActor func tabStride(game: LevelCatalog.Game) -> Float {
  let count = Float(levelCatalog.pagesByGame[game]?.count ?? 4)
  // Junkbot's 4 tabs use the CSS's exact -15px overlap; Undercover's 5 squeeze a little more
  // so the row still fits the window.
  return count <= 4 ? tabImageWidth - tabOverlap : (Float(windowWidth) - tabImageWidth - 4) / (count - 1)
}

@MainActor func showLevelSelectScreen(game: LevelCatalog.Game, page: Int) {
  currentScreen = .levelSelect(game: game, page: page)
  currentGame = game
  gameEngine.setPaused(true)
  levelToastUntil = nil

  let pages = levelCatalog.pagesByGame[game] ?? []
  let rowCount = pages[safe: page]?.count ?? 0
  let listBottom = levelSelectRowsTop + Float(rowCount) * levelSelectRowHeight + listPadY
  var buttons: [Button] = [
    // "Main" back-to-title button below the list, bottom-left - HTML5's #back-to-title
    // (lv_quit.png image button with a 15px margin after the list).
    Button(x: 15, y: listBottom + 8, width: 96, height: 26, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      showTitleScreen()
    })
  ]
  let stride = tabStride(game: game)
  for tabIndex in 0..<pages.count {
    buttons.append(
      Button(x: Float(tabIndex) * stride, y: 0, width: tabImageWidth, height: tabStripHeight, action: {
        guard tabIndex != page else { return }
        soundBoard.play(MenuSoundID.tabSwitch)
        showLevelSelectScreen(game: game, page: tabIndex)
      }))
  }
  for (rowIndex, entry) in (pages[safe: page] ?? []).enumerated() {
    buttons.append(
      Button(
        x: levelSelectRowsLeft, y: levelSelectRowsTop + Float(rowIndex) * levelSelectRowHeight,
        width: Float(windowWidth) - levelSelectRowsLeft * 2, height: levelSelectRowHeight,
        action: {
          loadLevel(entry, game: game)
          currentScreen = .playing
        }))
  }
  menuButtons = buttons
}

@MainActor func drawLevelSelectScreen(game: LevelCatalog.Game, page: Int) {
  // Page background (#7c857c).
  _ = SDL_SetRenderDrawColor(renderer, 0x7C, 0x85, 0x7C, 255)
  _ = SDL_RenderClear(renderer)

  // Tab strip: #33CCFF sky with the bottom 32px in #33CC33 grass (the CSS's inset box-shadow).
  var sky = SDL_FRect(x: 0, y: 0, w: Float(windowWidth), h: tabStripHeight - 32)
  _ = SDL_SetRenderDrawColor(renderer, 0x33, 0xCC, 0xFF, 255)
  _ = SDL_RenderFillRect(renderer, &sky)
  var grass = SDL_FRect(x: 0, y: tabStripHeight - 32, w: Float(windowWidth), h: 32)
  _ = SDL_SetRenderDrawColor(renderer, 0x33, 0xCC, 0x33, 255)
  _ = SDL_RenderFillRect(renderer, &grass)

  // Tabs, unselected first then the selected one on top (CSS z-index on .selected). Each is
  // custom/tab.png bottom-aligned, with the buidling_tab_N text image 2px above the bottom and
  // building_icon_N 12px above that (the CSS's margin-bottoms). Unselected tab text at 50%
  // opacity plus a 1px black baseline (the CSS's inset shadow on :not(.selected)).
  let pages = levelCatalog.pagesByGame[game] ?? []
  let stride = tabStride(game: game)
  let black = SDL_Color(r: 0, g: 0, b: 0, a: 255)
  func drawTab(_ tabIndex: Int, selected: Bool) {
    let x = Float(tabIndex) * stride
    drawMenuTexture("custom/tab", x: x, y: tabStripHeight - 22)
    if !selected {
      var baseline = SDL_FRect(x: x, y: tabStripHeight - 1, w: tabImageWidth, h: 1)
      _ = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
      _ = SDL_RenderFillRect(renderer, &baseline)
    }
    if game == .junkbot {
      drawMenuTexture(
        "buidling_tab_\(tabIndex + 1)", x: x + (tabImageWidth - 83) / 2, y: tabStripHeight - 2 - 13,
        alphaPercent: selected ? 100 : 50)
      drawMenuTexture(
        "building_icon_\(tabIndex + 1)", x: x + (tabImageWidth - 61) / 2,
        y: tabStripHeight - 2 - 13 - 12 - 38)
    } else {
      let label = "Basement \(tabIndex + 1)"
      let size = textRenderer.measure(label)
      textRenderer.draw(
        label, x: Int32(x + (tabImageWidth - Float(size.width)) / 2),
        y: Int32(tabStripHeight) - 16,
        color: selected ? black : SDL_Color(r: 255, g: 255, b: 255, a: 255))
    }
  }
  for tabIndex in 0..<pages.count where tabIndex != page {
    drawTab(tabIndex, selected: false)
  }
  drawTab(page, selected: true)

  // "Main" button: lv_quit.png with lv_quit_X.png hover (HTML5's #back-to-title).
  let mainButton = menuButtons[0]
  drawMenuTexture(
    mainButton.contains(lastMouseScreenX, lastMouseScreenY) ? "lv_quit_X" : "lv_quit",
    x: mainButton.x, y: mainButton.y)

  guard let entries = pages[safe: page] else { return }

  // List panel: #808080 with a 1px black outline (the CSS box-shadow).
  let listHeight = listPadY * 2 + Float(entries.count) * levelSelectRowHeight
  var listPanel = SDL_FRect(x: 0, y: tabStripHeight, w: Float(windowWidth), h: listHeight)
  _ = SDL_SetRenderDrawColor(renderer, 0x80, 0x80, 0x80, 255)
  _ = SDL_RenderFillRect(renderer, &listPanel)
  _ = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
  _ = SDL_RenderRect(renderer, &listPanel)

  // Rollover row highlight (#BFC0BF, the CSS :hover).
  let hoverRow = Int((lastMouseScreenY - levelSelectRowsTop) / levelSelectRowHeight)
  if lastMouseScreenY >= levelSelectRowsTop, hoverRow >= 0, hoverRow < entries.count {
    var bar = SDL_FRect(
      x: levelSelectRowsLeft, y: levelSelectRowsTop + Float(hoverRow) * levelSelectRowHeight,
      w: Float(windowWidth) - levelSelectRowsLeft * 2, h: levelSelectRowHeight)
    _ = SDL_SetRenderDrawColor(renderer, 0xBF, 0xC0, 0xBF, 255)
    _ = SDL_RenderFillRect(renderer, &bar)
  }

  for (rowIndex, entry) in entries.enumerated() {
    let rowY = levelSelectRowsTop + Float(rowIndex) * levelSelectRowHeight
    let textY = Int32(rowY) + (Int32(levelSelectRowHeight) - Font.characterHeight) / 2
    let completed = saveData.isCompleted(levelTitle: entry.title)
    let isGold = saveData.isGold(levelTitle: entry.title, par: entry.par)

    // #CCCCCC separators: top border on the first row, bottom border on every row (the CSS).
    _ = SDL_SetRenderDrawColor(renderer, 0xCC, 0xCC, 0xCC, 255)
    if rowIndex == 0 {
      var top = SDL_FRect(
        x: levelSelectRowsLeft, y: rowY, w: Float(windowWidth) - levelSelectRowsLeft * 2, h: 1)
      _ = SDL_RenderFillRect(renderer, &top)
    }
    var bottom = SDL_FRect(
      x: levelSelectRowsLeft, y: rowY + levelSelectRowHeight - 1,
      w: Float(windowWidth) - levelSelectRowsLeft * 2, h: 1)
    _ = SDL_RenderFillRect(renderer, &bottom)

    // Columns at the CSS's own offsets within the list padding: ordinal 2, checkbox 35,
    // gold check 48, title 63, score right-aligned.
    textRenderer.draw(
      "\(page * 15 + rowIndex + 1)", x: Int32(levelSelectRowsLeft) + 2, y: textY, color: black)
    drawMenuTexture(
      completed ? "checkbox_on" : "checkbox_off", x: levelSelectRowsLeft + 35,
      y: rowY + levelSelectRowHeight - 5 - 10)
    if isGold {
      drawMenuTexture(
        "check_light", x: levelSelectRowsLeft + 48, y: rowY + levelSelectRowHeight - 5 - 8)
    }
    textRenderer.draw(entry.title, x: Int32(levelSelectRowsLeft) + 63, y: textY, color: black)
    if let moves = saveData.bestMoves[entry.title] {
      let movesText = "\(moves)"
      let size = textRenderer.measure(movesText)
      textRenderer.draw(
        movesText, x: windowWidth - Int32(levelSelectRowsLeft) - size.width - 5, y: textY,
        color: black)
    }
  }
}

// MARK: - Win / lose dialogs

@MainActor var winDialogImprovedRecord = false

@MainActor func dialogButtonY() -> Float { Float(windowHeight) / 2 + 40 }

@MainActor func showLevelWinDialog() {
  currentScreen = .levelWinDialog
  guard let entry = currentLevelEntry else { return }
  winDialogImprovedRecord = saveData.recordWin(levelTitle: entry.title, moves: Int(gameEngine.moves))
  writeSaveData()

  let centerX = Float(windowWidth) / 2
  var buttons: [Button] = [
    Button(x: centerX - 150, y: dialogButtonY(), width: 140, height: 26, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      guard let location = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
      else { showTitleScreen(); return }
      showLevelSelectScreen(game: currentGame, page: location.page)
    })
  ]
  if let next = levelCatalog.nextLevel(after: entry.title, game: currentGame) {
    buttons.append(
      Button(x: centerX + 10, y: dialogButtonY(), width: 140, height: 26, action: {
        soundBoard.play(MenuSoundID.buttonClick)
        loadLevel(next, game: currentGame)
        currentScreen = .playing
      }))
  }
  menuButtons = buttons
}

@MainActor var loseDialogMessage = ""

/// The original's four messages (`behavior_msgBox_Fail.ls`); the HTML5 remake dropped "There's
/// got to be a better way." - keeping all four since the Lingo source is the more authoritative
/// reference for content.
let loseMessages = [
  "I hate Mondays.",
  "I knew that was going to happen.",
  "Why me?",
  "There's got to be a better way.",
]

@MainActor func showLevelLoseDialog() {
  currentScreen = .levelLoseDialog
  loseDialogMessage = loseMessages.randomElement() ?? ""
  guard let entry = currentLevelEntry else { return }
  let centerX = Float(windowWidth) / 2
  menuButtons = [
    Button(x: centerX - 150, y: dialogButtonY(), width: 140, height: 26, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      guard let location = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
      else { showTitleScreen(); return }
      showLevelSelectScreen(game: currentGame, page: location.page)
    }),
    Button(x: centerX + 10, y: dialogButtonY(), width: 140, height: 26, action: {
      soundBoard.play(MenuSoundID.buttonClick)
      loadLevel(entry, game: currentGame)
      currentScreen = .playing
    }),
  ]
}

@MainActor func drawDialogOverlay() {
  var dim = SDL_FRect(x: 0, y: 0, w: Float(windowWidth), h: Float(windowHeight))
  _ = SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
  _ = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 140)
  _ = SDL_RenderFillRect(renderer, &dim)

  let white = SDL_Color(r: 0, g: 0, b: 0, a: 255)
  let centerX = Float(windowWidth) / 2
  let panelW: Float = 360
  let panelH: Float = 170
  let panelX = centerX - panelW / 2
  let panelY = Float(windowHeight) / 2 - 110
  drawPanel(x: panelX, y: panelY, w: panelW, h: panelH)

  switch currentScreen {
  case .levelWinDialog:
    let heading = "Level Complete!"
    let headingSize = textRenderer.measure(heading)
    textRenderer.draw(
      heading, x: Int32(centerX) - headingSize.width, y: Int32(panelY) + 16, color: white,
      scale: 2)
    var detailY = Int32(panelY) + 44
    if winDialogImprovedRecord {
      textRenderer.draw(
        "Best: \(gameEngine.moves) moves", x: Int32(panelX) + 16, y: detailY, color: white)
      detailY += 14
    }
    if let entry = currentLevelEntry, let par = entry.par {
      if saveData.isGold(levelTitle: entry.title, par: par) {
        drawMenuTexture("gold_award", x: panelX + panelW - 76, y: panelY + 40)
      } else {
        // behavior_msgBox_Success.ls's msgbox_3 hint text.
        textRenderer.draw(
          "Beat this level in \(par) moves or fewer\nto get the gold award",
          x: Int32(panelX) + 16, y: detailY, color: white)
      }
    }
    drawButton(menuButtons[0], label: "Select Level")
    if menuButtons.count > 1 {
      drawButton(menuButtons[1], label: "Next Level")
    }

  case .levelLoseDialog:
    drawMenuTexture("level_lose", x: centerX - 74, y: panelY + 10)
    let messageSize = textRenderer.measure(loseDialogMessage)
    textRenderer.draw(
      loseDialogMessage, x: Int32(centerX) - messageSize.width / 2, y: Int32(panelY) + 76,
      color: white)
    drawButton(menuButtons[0], label: "Select Level")
    drawButton(menuButtons[1], label: "Retry")

  default:
    break
  }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
