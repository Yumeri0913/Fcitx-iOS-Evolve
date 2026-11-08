import Foundation
import SwiftUI
import SwiftUtil

struct SymbolCategory: Identifiable {
  var id: String { key }
  let key: String
  let name: String
  let symbols: [String]
  let symbolWidths: [String: SymbolWidth]
}

enum SymbolWidth {
  case halfWidth
  case fullWidth

  var badgeImageName: String {
    switch self {
    case .halfWidth:
      return "moon.fill"
    case .fullWidth:
      return "moonphase.full.moon"
    }
  }
}

private struct SymbolCategoryFile: Decodable {
  let name: [String: String]
  let symbols: [String]
  let halfWidth: [String]?
  let fullWidth: [String]?
}

// Category order follows Google Pinyin's symbol board:
// 常用 中文 英文 数学 特殊 序号 箭头 … then phonetic and scripts.
let builtinCategoryKeys = [
  "common",
  "chinese_punctuation",
  "english_punctuation",
  "math",
  "special",
  "sequence",
  "arrow",
  "unit",
  "currency",
  "shape",
  "superscript_subscript",
  "pinyin",
  "bopomofo",
  "greek",
  "cyrillic",
  "hiragana",
  "katakana",
  "latin",
  "phonetic",
  "radical",
]

let builtinCategories: [SymbolCategory] = {
  let locale = getLocale()
  let language = locale.split(whereSeparator: { $0 == "_" || $0 == "-" }).first.map(String.init)
  return builtinCategoryKeys.compactMap { key in
    let url = appBundleUrl.appendingPathComponent("share/symbol/\(key).json")
    do {
      let file = try JSONDecoder().decode(SymbolCategoryFile.self, from: Data(contentsOf: url))
      let name = file.name[locale] ?? language.flatMap { file.name[$0] } ?? file.name["en"] ?? key
      var symbolWidths: [String: SymbolWidth] = [:]
      for symbol in file.halfWidth ?? [] {
        symbolWidths[symbol] = .halfWidth
      }
      for symbol in file.fullWidth ?? [] {
        symbolWidths[symbol] = .fullWidth
      }
      return SymbolCategory(
        key: key, name: name, symbols: file.symbols, symbolWidths: symbolWidths)
    } catch {
      FCITX_ERROR("Failed to load symbol category \(key): \(error)")
      return nil
    }
  }
}()

let symbolColumnCount = 6
let symbolRowCount = 4  // visible rows of symbol keys, like Google Pinyin

/// One symbol key: a bordered key tile like the letter keys.
struct SymbolButton: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.keyBorder) var keyBorder

  let symbol: String
  let symbolWidth: SymbolWidth?
  let width: CGFloat
  let height: CGFloat
  let action: () -> Void

  @State private var isPressed = false

  var body: some View {
    let theme = currentTheme(colorScheme)
    Text(symbol)
      .font(.system(size: 20))
      .lineLimit(1)
      .minimumScaleFactor(0.4)
      .padding(.horizontal, 2)
      .foregroundColor(theme.keyTextColor)
      .frame(width: width - columnGap, height: height - columnGap)
      .background(keyBorder ? theme.keyBackgroundColor : Color.clear)
      .overlay(isPressed ? theme.keyPressHighlightColor : Color.clear)
      .cornerRadius(keyCornerRadius)
      .condition(keyBorder) {
        $0.overlay(
          ShadowView(
            width: width - columnGap, height: 1, radius: keyCornerRadius,
            color: theme.keyShadowColor
          )
          .offset(y: (height - columnGap - keyCornerRadius + 1) / 2)
        )
      }
      .overlay(alignment: .topTrailing) {
        if let symbolWidth {
          Image(systemName: symbolWidth.badgeImageName)
            .font(.system(size: 7))
            .foregroundColor(theme.altKeyTextColor)
            .padding(4 + columnGap / 2)
            .accessibilityHidden(true)
        }
      }
      .frame(width: width, height: height)
      .contentShape(Rectangle())
      .onTapGesture {
        action()
      }
      .onLongPressGesture(
        minimumDuration: .infinity,
        pressing: { pressing in
          if pressing {
            Haptic.keyPress()
          }
          isPressed = pressing
        }, perform: {})
  }
}

/// Google Pinyin style symbol board: category list on the left, a grid of
/// symbol keys on the right, and 返回 / 锁定 / 空格 / 删除 along the bottom.
struct SymbolView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  @State private var selectedKey = builtinCategories.first?.key ?? ""

  var body: some View {
    let theme = currentTheme(colorScheme)
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let bottomRowHeight = keyboardHeight / CGFloat(symbolRowCount + 1)
    let gridHeight = keyboardHeight - bottomRowHeight
    let categoryWidth = width * 0.18
    let gridWidth = width - categoryWidth
    let cellWidth = gridWidth / CGFloat(symbolColumnCount)
    let cellHeight = gridHeight / CGFloat(symbolRowCount)

    VStack(spacing: 0) {
      ToolbarView(width: width)
      HStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(builtinCategories) { category in
              let selected = selectedKey == category.key
              Text(category.name)
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? theme.accentKeyBackgroundColor : theme.altKeyTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
                .frame(width: categoryWidth, height: cellHeight)
                .background(selected ? theme.keyBackgroundColor : Color.clear)
                .overlay(alignment: .leading) {
                  if selected {
                    Rectangle().fill(theme.accentKeyBackgroundColor).frame(width: 3)
                  }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                  selectedKey = category.key
                }
            }
          }
        }
        .scrollIndicators(.hidden)
        .frame(width: categoryWidth, height: gridHeight)
        .background(theme.altKeyBackgroundColor)
        if let category = builtinCategories.first(where: { $0.key == selectedKey }) {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 0) {
                Color.clear.frame(height: 0).id("top")
                LazyVGrid(
                  columns: Array(
                    repeating: GridItem(.fixed(cellWidth), spacing: 0), count: symbolColumnCount),
                  spacing: 0
                ) {
                  ForEach(category.symbols, id: \.self) { symbol in
                    SymbolButton(
                      symbol: symbol, symbolWidth: category.symbolWidths[symbol],
                      width: cellWidth, height: cellHeight
                    ) {
                      client.resetInput()
                      client.commitString(symbol)
                      if !viewModel.symbolLocked {
                        vm.popDisplayMode()
                      }
                    }
                  }
                }
              }.onChange(of: selectedKey) { _ in
                proxy.scrollTo("top", anchor: .top)
              }
            }
            .scrollIndicators(.hidden)
            .frame(width: gridWidth, height: gridHeight)
          }
        }
      }
      SymbolBottomRow(width: width, height: bottomRowHeight, locked: $viewModel.symbolLocked)
    }
  }
}

struct SymbolBottomRow: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat
  @Binding var locked: Bool

  var body: some View {
    let backWidth = width * 0.18
    let lockWidth = width * 0.15
    let backspaceWidth = width * 0.15
    let spaceWidth = width - backWidth - lockWidth - backspaceWidth
    ZStack {
      Text(NSLocalizedString("Back", comment: ""))
        .font(.system(size: layoutSwitchFontSize, weight: .bold))
        .keyTile(
          x: 0, y: 0, width: backWidth, height: height, variant: .alternative,
          colorScheme: colorScheme, action: GestureAction(onTap: { vm.popDisplayMode() }),
          vMargin: columnGap)
      Image(systemName: locked ? "lock.fill" : "lock.open")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: keyIconHeight(height) * 0.8)
        .keyTile(
          x: backWidth, y: 0, width: lockWidth, height: height,
          variant: locked ? .accent : .alternative, colorScheme: colorScheme,
          action: GestureAction(onTap: { locked.toggle() }), vMargin: columnGap)
      Image(systemName: "space")
        .keyTile(
          x: backWidth + lockWidth, y: 0, width: spaceWidth, height: height, variant: .normal,
          colorScheme: colorScheme,
          action: GestureAction(onTap: {
            client.resetInput()
            client.commitString(" ")
          }), vMargin: columnGap)
      BackspaceView(
        x: width - backspaceWidth, y: 0, width: backspaceWidth, height: height,
        vMargin: columnGap)
    }
    .frame(width: width, height: height)
  }
}
