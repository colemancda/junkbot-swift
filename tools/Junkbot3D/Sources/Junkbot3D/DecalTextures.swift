import AppKit

/// Procedurally-drawn decal textures for Junkbot and the trash bin, replacing what would
/// otherwise be flat LDraw-sticker art. Generated at draw time (no image assets) via Core
/// Graphics, matching the "no source files, everything procedural" approach used for the
/// brick/stud geometry.
enum DecalTextures {
  /// The universal "chasing arrows" recycle glyph: two broken arcs, each capped with a small
  /// triangular arrowhead, drawn into whatever context is currently focused. `strokeColor` is
  /// used for both the arcs and the arrowheads; background (transparent or opaque) is the
  /// caller's responsibility.
  static func drawRecycleLoop(center: NSPoint, radius: CGFloat, strokeColor: NSColor, lineWidth: CGFloat) {
    strokeColor.setStroke()
    strokeColor.setFill()
    for half in 0..<2 {
      let start = CGFloat(half) * .pi + .pi / 10
      let end = start + .pi * 0.72
      let arc = NSBezierPath()
      arc.appendArc(
        withCenter: center, radius: radius, startAngle: start * 180 / .pi, endAngle: end * 180 / .pi)
      arc.lineWidth = lineWidth
      arc.lineCapStyle = .round
      arc.stroke()

      // Arrowhead at the arc's leading end, tangent to the circle there.
      let endRad = end
      let tip = NSPoint(
        x: center.x + radius * cos(endRad), y: center.y + radius * sin(endRad))
      let tangent = NSPoint(x: -sin(endRad), y: cos(endRad))
      let normal = NSPoint(x: cos(endRad), y: sin(endRad))
      let headLen = radius * 0.5
      let headWidth = radius * 0.4
      let base1 = NSPoint(
        x: tip.x - tangent.x * headLen + normal.x * headWidth * 0.5,
        y: tip.y - tangent.y * headLen + normal.y * headWidth * 0.5)
      let base2 = NSPoint(
        x: tip.x - tangent.x * headLen - normal.x * headWidth * 0.5,
        y: tip.y - tangent.y * headLen - normal.y * headWidth * 0.5)
      let head = NSBezierPath()
      head.move(to: tip)
      head.line(to: base1)
      head.line(to: base2)
      head.close()
      head.fill()
    }
  }

  /// Junkbot's front panel: the recycle glyph, debossed into the orange body color (darker
  /// strokes, no separate background fill so the box's own material color shows through).
  static func front(bodyColor: NSColor) -> NSImage {
    let size = NSSize(width: 128, height: 128)
    let image = NSImage(size: size)
    image.lockFocus()
    bodyColor.setFill()
    NSRect(origin: .zero, size: size).fill()

    let dark = bodyColor.blended(withFraction: 0.35, of: .black) ?? bodyColor
    drawRecycleLoop(
      center: NSPoint(x: 60, y: 56), radius: 26, strokeColor: dark, lineWidth: 7)

    image.unlockFocus()
    return image
  }

  /// Junkbot's side panel: full-height diagonal grille/vent ribs with a simple robot face — two
  /// dark almond eyes and a horizontal mouth slit — near the top, matching the reference art
  /// (not a separate "head", the whole torso side doubles as the face).
  static func side(bodyColor: NSColor) -> NSImage {
    let size = NSSize(width: 128, height: 128)
    let image = NSImage(size: size)
    image.lockFocus()
    bodyColor.setFill()
    NSRect(origin: .zero, size: size).fill()

    let dark = bodyColor.blended(withFraction: 0.35, of: .black) ?? bodyColor
    dark.setStroke()
    let grille = NSBezierPath()
    grille.lineWidth = 5
    var x: CGFloat = -20
    while x < 160 {
      grille.move(to: NSPoint(x: x, y: 128))
      grille.line(to: NSPoint(x: x - 40, y: -20))
      x += 14
    }
    grille.stroke()

    let eyeColor = bodyColor.blended(withFraction: 0.75, of: .black) ?? .black
    eyeColor.setFill()
    NSBezierPath(ovalIn: NSRect(x: 34, y: 78, width: 16, height: 11)).fill()
    NSBezierPath(ovalIn: NSRect(x: 58, y: 78, width: 16, height: 11)).fill()

    let mouth = NSBezierPath(
      roundedRect: NSRect(x: 34, y: 58, width: 40, height: 6), xRadius: 3, yRadius: 3)
    eyeColor.setFill()
    mouth.fill()

    image.unlockFocus()
    return image
  }

  /// A sticker-style recycle-loop decal on a transparent background, for the trash bin's front
  /// (applied via a flat plane rather than baked into a curved cylinder's wraparound UVs).
  static func recycleSticker(color: NSColor) -> NSImage {
    let size = NSSize(width: 96, height: 96)
    let image = NSImage(size: size)
    image.lockFocus()
    drawRecycleLoop(center: NSPoint(x: 48, y: 48), radius: 32, strokeColor: color, lineWidth: 9)
    image.unlockFocus()
    return image
  }
}
