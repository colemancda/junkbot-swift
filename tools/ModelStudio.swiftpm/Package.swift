// swift-tools-version: 6.0

// ModelStudio - a SwiftUI + SceneKit playground for authoring the low-poly 3D models the Nintendo
// DS port (ports/NDS) renders. Each model is written in a small Swift "3D DSL" (see MeshDSL.swift):
// a result-builder of primitives (Box, Stud, CylinderY, Cone, ...) that compiles straight to
// SceneKit geometry, previewed live on a turntable next to a sidebar list - a far faster iteration
// loop than rebuilding a .nds and loading it in an emulator. One file per model under Models/.
//
// Open in Swift Playgrounds (iPad/Mac) or Xcode. The DSL mirrors the DS's own `Mesh` primitives
// and stud-unit conventions, so a model dialed in here ports directly to the fixed-point DS
// builder.
import PackageDescription
import AppleProductTypes

let package = Package(
  name: "ModelStudio",
  platforms: [.iOS("17.0")],
  products: [
    .iOSApplication(
      name: "ModelStudio",
      targets: ["AppModule"],
      bundleIdentifier: "com.colemancda.modelstudio",
      teamIdentifier: "4W79SG34MW",
      displayVersion: "1.0",
      bundleVersion: "1",
      appIcon: .placeholder(icon: .box),
      accentColor: .presetColor(.orange),
      supportedDeviceFamilies: [.pad, .phone],
      supportedInterfaceOrientations: [
        .portrait, .landscapeLeft, .landscapeRight,
      ]
    )
  ],
  targets: [
    .executableTarget(name: "AppModule", path: ".")
  ]
)
