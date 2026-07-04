/// Which kind of pointing input the user touched last. Touch hides the OS cursor; mouse or
/// gamepad shows it. Shared across every native port (`ports/SDL3`'s `Input.swift`,
/// `ports/Darwin`'s `GameShell.swift`) so the cursor-visibility/virtual-cursor logic in
/// `GameRender.swift` only needs one definition to switch over.
public enum PointingInputKind {
  case mouse
  case gamepad
  case touch
}
