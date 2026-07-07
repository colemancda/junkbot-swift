// swift-tools-version: 6.0
import PackageDescription

// Standalone macOS SceneKit prototype that renders a real Junkbot level in low-poly 3D
// (PS1/Nintendo-DS aesthetic). Reuses JunkbotCore for the *exact* entity data the game
// simulates, so what we render is what the game actually contains. This is Phase 1 of the
// 3D rendering refactor: generate procedural brick/character meshes and render offline to a
// PNG so the art direction can be iterated on before wiring 3D into the live game loop.
let package = Package(
  name: "Junkbot3D",
  platforms: [.macOS(.v14)],
  dependencies: [
    // Explicit name: path-based identity is the checkout's directory name, which isn't
    // "junkbot-swift" inside a git worktree (mirrors tools/LevelDump).
    .package(name: "junkbot-swift", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "Junkbot3D",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift")
      ]
    )
  ]
)
