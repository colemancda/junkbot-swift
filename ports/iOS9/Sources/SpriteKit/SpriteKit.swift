@_exported import UIKit
import JunkbotBackend

// The SpriteKit API the shared Junkbot renderer and scene use, wrapping iOS 9's
// SpriteKit through the backend. Properties the game only sets are passed
// straight through.

public typealias SKColor = UIColor

public enum SKSceneScaleMode: Int {
    case fill
    case aspectFill
    case aspectFit
    case resizeFill
}

public enum SKTextureFilteringMode: Int {
    case nearest
    case linear
}

@MainActor
public final class SKView {
    let pointer: UnsafeMutableRawPointer

    /// The presented scene, kept alive here since the backend's scene only
    /// holds an unretained reference back to it.
    public private(set) var scene: SKScene?

    /// Wraps the backend's view, which the app's window owns.
    public init(_ pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    public var ignoresSiblingOrder = false {
        didSet { jb_view_set_ignores_sibling_order(pointer, ignoresSiblingOrder ? 1 : 0) }
    }

    public func presentScene(_ scene: SKScene?) {
        self.scene = scene
        if let scene {
            scene.view = self
            jb_view_present_scene(pointer, scene.pointer)
        }
    }
}

@MainActor
open class SKNode: _BackendObject {
    public var position = CGPoint.zero {
        didSet { jb_node_set_position(pointer, _bits(position.x), _bits(position.y)) }
    }

    public var zPosition: CGFloat = 0 {
        didSet { jb_node_set_z_position(pointer, _bits(zPosition)) }
    }

    public var zRotation: CGFloat = 0 {
        didSet { jb_node_set_z_rotation(pointer, _bits(zRotation)) }
    }

    public var alpha: CGFloat = 1 {
        didSet { jb_node_set_alpha(pointer, _bits(alpha)) }
    }

    public func addChild(_ node: SKNode) {
        jb_node_add_child(pointer, node.pointer)
    }

    public func removeFromParent() {
        jb_node_remove_from_parent(pointer)
    }
}

/// A scene whose events call the overridable methods below.
@MainActor
open class SKScene: SKNode {
    public let size: CGSize

    public init(size: CGSize) {
        self.size = size
        SKScene.installHandlers
        super.init(retained: jb_scene_create(_bits(size.width), _bits(size.height)))
        jb_scene_set_context(pointer, Unmanaged.passUnretained(self).toOpaque())
    }

    public var backgroundColor = SKColor.black {
        didSet {
            jb_scene_set_background_color(
                pointer, _bits(backgroundColor.red), _bits(backgroundColor.green),
                _bits(backgroundColor.blue), _bits(backgroundColor.alpha))
        }
    }

    public var scaleMode = SKSceneScaleMode.fill {
        didSet { jb_scene_set_scale_mode(pointer, scaleMode.rawValue) }
    }

    open func didMove(to view: SKView) {}

    open func update(_ currentTime: TimeInterval) {}

    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}

    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}

    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}

    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

    private static let installHandlers: Void = {
        var handlers = jb_scene_handlers(
            did_move: { context, view in
                MainActor.assumeIsolated {
                    let scene = SKScene.from(context)
                    scene.didMove(to: scene.view!)
                }
            },
            update: { context, currentTime in
                MainActor.assumeIsolated {
                    SKScene.from(context).update(currentTime!.pointee)
                }
            },
            touches: { context, phase, touches, count, event in
                MainActor.assumeIsolated {
                    var set = Set<UITouch>()
                    for index in 0..<count {
                        set.insert(UITouch(unretained: touches![index]!))
                    }
                    let event = event.map { UIEvent(unretained: $0) }
                    let scene = SKScene.from(context)
                    switch phase {
                    case 0: scene.touchesBegan(set, with: event)
                    case 1: scene.touchesMoved(set, with: event)
                    case 2: scene.touchesEnded(set, with: event)
                    default: scene.touchesCancelled(set, with: event)
                    }
                }
            }
        )
        jb_scene_set_handlers(&handlers)
    }()

    /// The view presenting this scene.
    public internal(set) var view: SKView?

    private static func from(_ context: UnsafeMutableRawPointer?) -> SKScene {
        Unmanaged<SKScene>.fromOpaque(context!).takeUnretainedValue()
    }
}

public final class SKTexture {
    /// The backend texture, shared by every `SKTexture` showing the same part
    /// of the same image.
    final class Storage: _BackendObject {
        /// Sub-textures made by `init(rect:in:)`, reused since the game asks
        /// for the same font glyphs and clipped sprites every frame.
        var subtextures: [RectKey: Storage] = [:]

        var filteringMode = SKTextureFilteringMode.linear {
            didSet { jb_texture_set_filtering_mode(pointer, filteringMode.rawValue) }
        }
    }

    struct RectKey: Hashable {
        let x, y, width, height: CGFloat
    }

    let storage: Storage

    public init(image: UIImage) {
        storage = Storage(retained: jb_texture_create(image.pointer))
    }

    /// The part of `texture` in `rect`, in unit coordinates with the origin at
    /// the bottom left.
    public init(rect: CGRect, in texture: SKTexture) {
        let key = RectKey(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        if let storage = texture.storage.subtextures[key] {
            self.storage = storage
        } else {
            storage = Storage(retained: jb_texture_create_rect(
                texture.storage.pointer, _bits(rect.origin.x), _bits(rect.origin.y),
                _bits(rect.size.width), _bits(rect.size.height)))
            storage.filteringMode = texture.storage.filteringMode
            texture.storage.subtextures[key] = storage
        }
    }

    /// Sub-textures start with their texture's filtering mode.
    public var filteringMode: SKTextureFilteringMode {
        get { storage.filteringMode }
        set { storage.filteringMode = newValue }
    }

    public func size() -> CGSize {
        var size: (Float, Float) = (0, 0)
        withUnsafeMutablePointer(to: &size) {
            $0.withMemoryRebound(to: Float.self, capacity: 2) { jb_texture_size(storage.pointer, $0) }
        }
        return CGSize(width: CGFloat(size.0), height: CGFloat(size.1))
    }
}

@MainActor
public final class SKSpriteNode: SKNode {
    public init(texture: SKTexture?, size: CGSize) {
        super.init(retained: jb_sprite_create(texture?.storage.pointer, _bits(size.width), _bits(size.height)))
    }

    public var color = SKColor.white {
        didSet { jb_sprite_set_color(pointer, _bits(color.red), _bits(color.green), _bits(color.blue), _bits(color.alpha)) }
    }

    public var colorBlendFactor: CGFloat = 0 {
        didSet { jb_sprite_set_color_blend_factor(pointer, _bits(colorBlendFactor)) }
    }
}

@MainActor
public final class SKShapeNode: SKNode {
    public init(rect: CGRect) {
        super.init(retained: jb_shape_create_rect(
            _bits(rect.origin.x), _bits(rect.origin.y), _bits(rect.size.width), _bits(rect.size.height)))
    }

    public init(path: CGMutablePath) {
        super.init(retained: jb_shape_create_path(path.pointer))
    }

    public var fillColor = SKColor.clear {
        didSet { jb_shape_set_fill_color(pointer, _bits(fillColor.red), _bits(fillColor.green), _bits(fillColor.blue), _bits(fillColor.alpha)) }
    }

    public var strokeColor = SKColor.white {
        didSet { jb_shape_set_stroke_color(pointer, _bits(strokeColor.red), _bits(strokeColor.green), _bits(strokeColor.blue), _bits(strokeColor.alpha)) }
    }

    public var lineWidth: CGFloat = 1 {
        didSet { jb_shape_set_line_width(pointer, _bits(lineWidth)) }
    }
}

extension UITouch {
    @MainActor
    public func location(in node: SKNode) -> CGPoint {
        var point: (Float, Float) = (0, 0)
        withUnsafeMutablePointer(to: &point) {
            $0.withMemoryRebound(to: Float.self, capacity: 2) { jb_touch_location(pointer, node.pointer, $0) }
        }
        return CGPoint(x: CGFloat(point.0), y: CGFloat(point.1))
    }
}
