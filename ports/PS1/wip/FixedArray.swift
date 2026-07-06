// FixedArray.swift — a fixed-capacity, InlineArray-backed stand-in for
// `Array` on this port. See KNOWN_ISSUES.md: this experimental
// mipsel-none-none-elf Embedded Swift target has confirmed codegen bugs in
// `Array`/`Dictionary`'s dynamic heap-buffer machinery (growth past an
// existing capacity, and even `removeAll(keepingCapacity:)` on an empty,
// already-reserved array) — reproduced in isolation in
// ~/Developer/swift-embedded-ps1's `Sources/ArrayTests` example.
// `InlineArray<N, Element>` (SE-0453) is fixed-size, inline storage, no heap
// allocation, no COW, no growth — confirmed working on this exact
// toolchain/target by that same example's tests 7/8 (literal init,
// `repeating:` init, subscript read/write, iteration all correct).
//
// This is intentionally a small subset of Array's API: only what
// GameState/PS1Simulation/PS1Collision/PS1Input/Renderer actually need.

struct FixedArray<let N: Int, Element> {
  private var storage: InlineArray<N, Element>
  private(set) var count: Int = 0

  /// `placeholder` fills every slot up front (InlineArray has no
  /// uninitialized state) -- never read except transiently for indices
  /// `>= count`, which no code here ever does on purpose.
  init(repeating placeholder: Element) {
    storage = InlineArray<N, Element>(repeating: placeholder)
  }

  var isEmpty: Bool { count == 0 }
  var capacity: Int { N }

  mutating func append(_ element: Element) {
    precondition(count < N, "FixedArray<\(N)> overflow")
    storage[count] = element
    count += 1
  }

  /// Resets to empty. No deinitialization/copy needed (unlike
  /// `Array.removeAll(keepingCapacity:)`, which is one of this target's two
  /// confirmed-broken operations) -- just resets the logical count.
  mutating func removeAll() {
    count = 0
  }

  /// O(1) removal that doesn't preserve order (fine everywhere this is used
  /// -- entities/effects/index lists have no ordering requirement).
  mutating func removeSwap(at index: Int) {
    precondition(index < count, "FixedArray index out of bounds")
    storage[index] = storage[count - 1]
    count -= 1
  }

  subscript(index: Int) -> Element {
    get {
      precondition(index < count, "FixedArray index out of bounds")
      return storage[index]
    }
    set {
      precondition(index < count, "FixedArray index out of bounds")
      storage[index] = newValue
    }
  }
}

extension FixedArray: Sequence {
  struct Iterator: IteratorProtocol {
    let array: FixedArray<N, Element>
    var index = 0
    mutating func next() -> Element? {
      guard index < array.count else { return nil }
      defer { index += 1 }
      return array[index]
    }
  }

  func makeIterator() -> Iterator {
    Iterator(array: self)
  }
}
