import SceneKit
import SwiftUI

/// A live turntable preview of a `Model`: the model auto-rotates under a directional + ambient
/// light rig chosen to read like the DS renderer (strong ambient floor so no face goes black, one
/// key light from the upper-front so tops are brightest). Drag to orbit the camera.
struct ModelSceneView: View {
  let model: Model

  var body: some View {
    SceneView(
      scene: makeScene(),
      options: [.allowsCameraControl, .rendersContinuously]
    )
    .background(Color(white: 0.06))
    // Rebuild the scene when the selected model changes.
    .id(model.id)
  }

  private func makeScene() -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = PlatformColor(white: 0.06, alpha: 1)

    // Model, centered and auto-rotating.
    let node = model.makeNode()
    let pivot = SCNNode()
    pivot.addChildNode(node)
    pivot.runAction(
      .repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 8)))
    scene.rootNode.addChildNode(pivot)

    // Camera, framed on the model, tilted slightly down to see the tops (studs).
    let camera = SCNCamera()
    camera.usesOrthographicProjection = false
    camera.fieldOfView = 32
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, 1.6, 6.5)
    cameraNode.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(cameraNode)

    // Ambient floor.
    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.color = PlatformColor(white: 0.55, alpha: 1)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    // Key directional light from the upper-front (matches the DS's ~(0.27, 0.87, -0.41) sun).
    let sun = SCNLight()
    sun.type = .directional
    sun.color = PlatformColor(white: 0.9, alpha: 1)
    let sunNode = SCNNode()
    sunNode.light = sun
    sunNode.position = SCNVector3(-2, 5, 3)
    sunNode.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(sunNode)

    return scene
  }
}
