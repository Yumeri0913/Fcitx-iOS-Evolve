import SwiftUI

// Key press preview and long press popup keyboard, drawn like fcitx5-android's
// PopupEntryUi / PopupKeyboardUi: a rounded rectangle directly above the key,
// each cell the size of the key tile, the focused cell filled with the active color.

struct BubbleItem: Equatable {
  let label: String?
  let type: String?

  static func text(_ label: String) -> BubbleItem {
    BubbleItem(label: label, type: nil)
  }
}

let popupShadowRadius: CGFloat = 2  // elevation 2 dp

struct BubbleView: View {
  @Environment(\.colorScheme) var colorScheme

  /// Key tile center.
  let x: CGFloat
  let y: CGFloat
  /// Key tile size (key size minus gaps).
  let width: CGFloat
  let height: CGFloat
  let keyboardWidth: CGFloat
  let background: Color
  let shadow: Color
  let label: String?
  let items: [BubbleItem]
  /// Preferred column to place over the key.
  let index: Int
  let highlight: Int
  let fontSize: CGFloat?

  @ViewBuilder
  private func itemView(_ item: BubbleItem, active: Bool) -> some View {
    let theme = currentTheme(colorScheme)
    let foreground = active ? theme.genericActiveForegroundColor : theme.popupTextColor
    if let type = item.type, let symbol = popupItemSymbol(type) {
      Image(systemName: symbol)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: keyIconSize, height: keyIconSize)
        .foregroundColor(foreground)
    } else {
      Text(item.label ?? "")
        .font(.system(size: fontSize ?? popupFontSize))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundColor(foreground)
    }
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    let cells: [BubbleItem] = label.map { [.text($0)] } ?? items
    let isPreview = label != nil
    let count = cells.count
    let columns = popupColumns(count)
    let rows = popupRows(count)
    let totalWidth = width * CGFloat(columns)
    let totalHeight = height * CGFloat(rows)
    let left = popupLeft(
      keyCenterX: x, cellWidth: width, columns: columns, preferredColumn: index,
      keyboardWidth: keyboardWidth)
    // Bottom row sits where the key tile is; the popup covers the key like Android's
    // popup entry, which is anchored to the key and extends one key height upward.
    let bottom = y + height / 2 - height
    let centerX = left + totalWidth / 2
    let centerY = bottom - totalHeight / 2

    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: keyCornerRadius)
        .fill(background)
        .shadow(color: shadow, radius: popupShadowRadius, y: 1)
      ForEach(0..<count, id: \.self) { i in
        // Row 0 is the bottom row, filled first, like PopupKeyboardUi.
        let row = i / columns
        let column = i % columns
        let active = !isPreview && count > 1 && i == highlight
        ZStack {
          if active {
            RoundedRectangle(cornerRadius: keyCornerRadius)
              .fill(theme.genericActiveBackgroundColor)
          }
          itemView(cells[i], active: active)
        }
        .frame(width: width, height: height)
        .offset(x: CGFloat(column) * width, y: CGFloat(rows - 1 - row) * height)
      }
    }
    .frame(width: totalWidth, height: totalHeight)
    .position(x: centerX, y: centerY)
    .allowsHitTesting(false)
  }
}

func popupItemSymbol(_ type: String) -> String? {
  switch type {
  case "unicode":
    return "u.circle"
  case "quickphrase":
    return "q.circle"
  case "emoji":
    return "face.smiling"
  default:
    return nil
  }
}
