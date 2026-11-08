import SwiftUI
import SwiftUtil

/// Horizontal placement of a row, as fcitx5-android `BaseKeyboard`:
/// fixed percent widths, 0 fills the remaining space, and a row narrower
/// than the keyboard is centered.
func keyPositions(_ row: [KeyDef], _ width: CGFloat) -> [(x: CGFloat, width: CGFloat)] {
  let fixed = row.map { $0.percentWidth }.filter { $0 > 0 }.reduce(0, +)
  let fills = row.filter { $0.percentWidth == 0 }.count
  let fillWidth = fills > 0 ? max(0, 1 - fixed) / CGFloat(fills) : 0
  var x = fills > 0 ? 0 : max(0, 1 - fixed) / 2 * width
  var result = [(x: CGFloat, width: CGFloat)]()
  result.reserveCapacity(row.count)
  for def in row {
    let w = (def.percentWidth > 0 ? def.percentWidth : fillWidth) * width
    result.append((x, w))
    x += w
  }
  return result
}

/// Google Pinyin cancels a press 0.3 inch away from the key.
let slideCancelDistance: CGFloat = 0.3 * 163

/// Edge touch extension of a row's first and last key, as Google Pinyin's a and l
/// reach the screen edges.
func rowHitExtension(_ positions: [(x: CGFloat, width: CGFloat)], _ width: CGFloat)
  -> (leading: CGFloat, trailing: CGFloat)
{
  guard let first = positions.first, let last = positions.last else { return (0, 0) }
  return (first.x, max(0, width - last.x - last.width))
}

/// Letter key cells of the text keyboard in KeyboardRowsView coordinates, for touch
/// correction and for typing the key a finger slid onto.
struct LetterGeometry {
  private var cells = [Character: CGRect]()
  private var hitCells = [Character: CGRect]()
  let model: SpatialModel

  init(layout: [[KeyDef]], width: CGFloat, height: CGFloat) {
    let rowHeight = height / CGFloat(layout.count)
    for (i, row) in layout.enumerated() {
      let positions = keyPositions(row, width)
      let ext = rowHitExtension(positions, width)
      for (j, def) in row.enumerated() {
        guard case .alphabet(let letter, _) = def.kind, let char = letter.first else { continue }
        let cell = CGRect(
          x: positions[j].x, y: CGFloat(i) * rowHeight, width: positions[j].width,
          height: rowHeight)
        cells[char] = cell
        let leading = j == 0 ? ext.leading : 0
        let trailing = j == row.count - 1 ? ext.trailing : 0
        hitCells[char] = CGRect(
          x: cell.minX - leading, y: cell.minY, width: cell.width + leading + trailing,
          height: cell.height)
      }
    }
    model = SpatialModel(
      keys: cells.map { SpatialModel.Key(char: $0.key, rect: $0.value) })
  }

  func letter(at point: CGPoint) -> Character? {
    hitCells.first { $0.value.contains(point) }?.key
  }

  func distance(from char: Character, to point: CGPoint) -> CGFloat {
    guard let cell = hitCells[char] else { return .infinity }
    return SpatialModel.Key(char: char, rect: cell).distance(to: point)
  }
}

/// Renders rows of `KeyDef`; shared by the text and number keyboards.
struct KeyboardRowsView: View {
  let layout: [[KeyDef]]
  let width: CGFloat
  let height: CGFloat
  let layer: String
  let lock: Bool
  let spaceLabel: String
  let returnKeyType: UIReturnKeyType?
  let hasPreedit: Bool

  var body: some View {
    let rowHeight = height / CGFloat(layout.count)
    let geometry = LetterGeometry(layout: layout, width: width, height: height)
    ZStack {
      ForEach(Array(layout.enumerated()), id: \.offset) { i, row in
        rowView(row, CGFloat(i) * rowHeight, rowHeight, geometry)
      }
    }
    .frame(width: width, height: height)
  }

  @ViewBuilder
  private func rowView(
    _ row: [KeyDef], _ y: CGFloat, _ height: CGFloat, _ geometry: LetterGeometry
  ) -> some View {
    let positions = keyPositions(row, width)
    let ext = rowHitExtension(positions, width)
    ForEach(Array(row.enumerated()), id: \.offset) { i, def in
      keyView(
        def, x: positions[i].x, y: y, width: positions[i].width, height: height,
        geometry: geometry, hitLeading: i == 0 ? ext.leading : 0,
        hitTrailing: i == row.count - 1 ? ext.trailing : 0)
    }
  }

  @ViewBuilder
  private func keyView(
    _ def: KeyDef, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
    geometry: LetterGeometry, hitLeading: CGFloat, hitTrailing: CGFloat
  ) -> some View {
    let shifted = layer == "shift"
    switch def.kind {
    case .alphabet(let letter, let alt):
      AlphabetKeyView(
        x: x, y: y, width: width, height: height, letter: letter, alt: alt, shifted: shifted,
        geometry: geometry, hitLeading: hitLeading, hitTrailing: hitTrailing)
    case .symbol(let symbol):
      SymbolKeyView(
        x: x, y: y, width: width, height: height, symbol: symbol, variant: def.variant)
    case .comma:
      CommaKeyView(x: x, y: y, width: width, height: height, variant: def.variant)
    case .caps:
      // Google Pinyin turns shift into the syllable separator while composing,
      // unless caps lock is on.
      if hasPreedit && !(shifted && lock) && !vm.englishMode {
        SeparatorKeyView(x: x, y: y, width: width, height: height)
      } else {
        CapsKeyView(
          x: x, y: y, width: width, height: height,
          state: shifted ? (lock ? .capslock : .shift) : .normal)
      }
    case .backspace:
      BackspaceView(x: x, y: y, width: width, height: height, variant: def.variant)
    case .layoutSwitch(let label, let target):
      LayoutSwitchKeyView(
        x: x, y: y, width: width, height: height, label: label, target: target,
        variant: def.variant, fontSize: def.fontSize)
    case .globe:
      GlobeView(x: x, y: y, width: width, height: height)
    case .space:
      SpaceView(x: x, y: y, width: width, height: height, label: spaceLabel, forward: false)
    case .enter:
      EnterView(
        x: x, y: y, width: width, height: height, returnKeyType: returnKeyType, cr: hasPreedit)
    case .numPad(let label, let code):
      NumPadKeyView(
        x: x, y: y, width: width, height: height, label: label, code: code,
        variant: def.variant, fontSize: def.fontSize)
    case .miniSpace:
      MiniSpaceView(x: x, y: y, width: width, height: height, variant: def.variant)
    }
  }
}

struct KeyboardView: View {
  @Environment(\.totalHeight) var totalHeight

  let width: CGFloat
  let layer: String
  let lock: Bool
  let spaceLabel: String
  let returnKeyType: UIReturnKeyType?
  let hasPreedit: Bool

  let bubbleX: CGFloat
  let bubbleY: CGFloat
  let bubbleWidth: CGFloat
  let bubbleHeight: CGFloat
  let bubbleBackground: Color
  let bubbleShadow: Color
  let bubbleLabel: String?
  let bubbleItems: [BubbleItem]
  let bubbleIndex: Int
  let bubbleHighlight: Int
  let bubbleFontSize: CGFloat?

  var body: some View {
    let keyboardHeight = getKeyboardHeight(totalHeight)

    ZStack {
      KeyboardRowsView(
        layout: KeyboardLayouts.text, width: width, height: keyboardHeight, layer: layer,
        lock: lock, spaceLabel: spaceLabel, returnKeyType: returnKeyType, hasPreedit: hasPreedit)
      if bubbleLabel != nil || !bubbleItems.isEmpty {
        BubbleView(
          x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight,
          keyboardWidth: width, background: bubbleBackground, shadow: bubbleShadow,
          label: bubbleLabel, items: bubbleItems, index: bubbleIndex,
          highlight: bubbleHighlight, fontSize: bubbleFontSize)
      }
    }
    .frame(width: width, height: keyboardHeight)
  }
}
