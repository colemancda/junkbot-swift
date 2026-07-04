import CSDL2

/// A minimal rect-hit-test clickable region for menu UI (title screen's Play/Credits,
/// level-select's tabs/rows/back button, win/lose dialog buttons) - the native equivalent of
/// `src/game.js`'s DOM `<button>`/`<a href="#...">` elements, which have no SDL analogue.
struct Button {
  var x: Float
  var y: Float
  var width: Float
  var height: Float
  let action: () -> Void

  func contains(_ pointX: Float, _ pointY: Float) -> Bool {
    pointX >= x && pointX < x + width && pointY >= y && pointY < y + height
  }
}

/// Hit-tests `point` against `buttons` in reverse order (topmost/last-added wins on overlap) and
/// invokes the first match's action, mirroring standard UI hit-testing (and matching how DOM
/// z-order would resolve an overlapping click).
@discardableResult
func handleClick(_ buttons: [Button], at x: Float, y: Float) -> Bool {
  for button in buttons.reversed() where button.contains(x, y) {
    button.action()
    return true
  }
  return false
}
