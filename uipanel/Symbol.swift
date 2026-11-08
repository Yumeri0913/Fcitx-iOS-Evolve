import Foundation
import SwiftUI
import SwiftUtil

/// Chinese symbol keyboard of Google Pinyin 4.5.2 (keyboard_non_prime_symbol_zh), from
/// InsightKey's GooglePinyinSymbols.kt: category tabs on top (recent, 常用, 括号, 箭头,
/// 数学符号, 数字, 图形), pages of 28 symbols in rows of 10/10/8 with backspace, and a
/// bottom row of 返回 ， 123 space 。 return (150/100/100/400/100/150).
struct SymbolCategory {
  let label: String
  let symbols: [String]
}

let googlePinyinSymbolCategories: [SymbolCategory] = [
  SymbolCategory(
    label: "1?#",
    symbols: [
      "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
      "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
      "“", "”", "=", "、", "：", "；", "？", "！", "～", "+",
      "-", "/", "\\", "|", "[", "]", "{", "}", "…", "·",
      "<", ">", "—", "_", "‘", "’", "'", "\"", "`", ":",
      ";", "?", "~", "／", "¡", "¿", "￥", "€", "£", "¢",
      "©", "®", "™", "‖", "‗", "‚", "„", "†", "‡", "‥",
      "※", "‼", "⁇", "⁈", "⁉", "℃", "℉", "°", "§", "№",
      "¤", "µ", "々", "〒",
    ]),
  SymbolCategory(
    label: "( )",
    symbols: [
      "(", ")", "[", "]", "{", "}", "（", "）", "［", "］",
      "｛", "｝", "❨", "❩", "❲", "❳", "❴", "❵", "‘", "’",
      "“", "”", "❛", "❜", "❝", "❞", "<", ">", "〈", "〉",
      "《", "》", "〔", "〕", "【", "】", "〘", "〙", "「", "」",
      "『", "』", "︵", "︶", "︷", "︸", "︹", "︺", "︻", "︼",
      "︽", "︾", "︿", "﹀", "﹁", "﹂",
    ]),
  SymbolCategory(
    label: "⇄",
    symbols: [
      "←", "↑", "→", "↓", "↔", "↕", "↖", "↗", "↘", "↙",
      "↚", "↛", "↜", "↝", "↞", "↟", "↠", "↡", "↢", "↣",
      "↤", "↥", "↦", "↧", "↨", "↩", "↪", "↫", "↬", "↭",
      "↮", "↯", "↰", "↱", "↲", "↳", "↴", "↵", "↶", "↷",
      "↸", "↹", "↺", "↻", "↼", "↽", "↾", "↿", "⇀", "⇁",
      "⇂", "⇃", "⇄", "⇅", "⇆", "⇇", "⇈", "⇉", "⇊", "⇋",
      "⇌", "⇍", "⇎", "⇏", "⇐", "⇑", "⇒", "⇓", "⇔", "⇕",
      "⇖", "⇗", "⇘", "⇙", "⇚", "⇛", "⇜", "⇝", "⇞", "⇟",
      "⇠", "⇡", "⇢", "⇣",
    ]),
  SymbolCategory(
    label: "±",
    symbols: [
      "+", "-", "×", "÷", "±", "=", "≠", "∼", "≈", "≡",
      "<", "≤", "≦", "≪", "≮", ">", "≥", "≧", "≫", "≯",
      "⊕", "⊗", "%", "‰", "∀", "∂", "∃", "∅", "∆", "∇",
      "∈", "∉", "∋", "∌", "∏", "∑", "√", "∝", "∞", "∟",
      "∠", "∧", "∨", "∣", "∥", "∩", "∪", "∫", "∬", "∮",
      "∴", "∵", "∶", "∷", "⊂", "⊃", "⊄", "⊅", "⊆", "⊇",
      "∪", "∩", "ⁿ", "α", "β", "γ", "δ", "ε", "ζ", "η",
      "θ", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ρ",
      "ς", "σ", "τ", "υ", "φ", "χ", "ψ", "ω", "Α", "Β",
      "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Ι", "Κ", "Λ", "Μ",
      "Ν", "Ξ", "Ο", "Π", "Ρ", "Σ", "Τ", "Υ", "Φ", "Χ",
      "Ψ", "Ω",
    ]),
  SymbolCategory(
    label: "①",
    symbols: [
      "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
      "⑴", "⑵", "⑶", "⑷", "⑸", "⑹", "⑺", "⑻", "⑼", "⑽",
      "❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾", "❿",
      "㈠", "㈡", "㈢", "㈣", "㈤", "㈥", "㈦", "㈧", "㈨", "㈩",
      "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ",
      "Ⅺ", "Ⅻ", "Ⅼ", "Ⅽ", "Ⅾ", "Ⅿ", "ⅰ", "ⅱ", "ⅲ", "ⅳ",
      "ⅴ", "ⅵ", "ⅶ", "ⅷ", "ⅸ", "ⅹ", "ⅺ", "ⅻ", "ⅼ", "ⅽ",
      "ⅾ", "ⅿ", "¹", "²", "³", "⁴", "₁", "₂", "₃", "₄",
      "½", "⅓", "⅔", "㊣",
    ]),
  SymbolCategory(
    label: "◇",
    symbols: [
      "⚫", "⚪", "●", "○", "■", "□", "⬛", "⬜", "★", "☆",
      "◆", "◇", "▲", "△", "▶", "▷", "▼", "▽", "◀", "◁",
      "◐", "◑", "♀", "♂", "♤", "♡", "♧", "♢", "♠", "♥",
      "♣", "♦", "•", "❖", "✓", "✔", "✕", "✖", "✗", "✘",
      "✙", "✚", "✛", "✜", "✝", "✞", "✟", "✠", "✡", "✢",
      "✣", "✤", "✥", "✦", "✧", "✨", "✩", "✪", "✫", "✬",
      "✭", "✮", "✯", "✰", "✱", "✲", "✳", "✴", "✵", "✶",
      "✷", "✸", "✹", "✺", "✻", "✼", "✽", "✾", "✿", "❀",
      "❁", "❂", "❃", "❄", "❅", "❆", "❇", "❈", "❉", "❊",
      "❋", "❌", "❍", "❎", "❏", "❐", "❑", "❒", "◈", "◉",
      "◊", "○", "◢", "◣", "◤", "◥", "❢", "❣", "❤", "卍",
      "卐", "囍",
    ]),
]

/// Google Pinyin's long press options; symbols not listed have none.
let googlePinyinSymbolLongPress: [String: [String]] = [
  "1": ["¹", "½", "⅓", "¼", "⅛"],
  "2": ["²", "⅔"],
  "3": ["³", "¾", "⅜"],
  "4": ["⁴"],
  "5": ["⅝"],
  "7": ["⅞"],
  "0": ["∅", "ⁿ"],
  "!": ["¡"],
  "$": ["¢", "€", "£", "₱", "¥"],
  "%": ["‰"],
  "^": ["↑", "↓", "←", "→"],
  "*": ["★", "†", "‡"],
  "(": ["<", "{", "["],
  ")": [">", "}", "]"],
  "=": ["≠", "≈", "∞"],
  "+": ["±"],
  "-": ["—", "_", "–", "·"],
  "<": ["≤", "‹", "«"],
  ">": ["≥", "›", "»"],
]

let symbolsPerPage = 28

/// Recently committed symbols, Google Pinyin's first category.
enum RecentSymbols {
  private static let key = "RecentSymbols"

  static func load() -> [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  static func add(_ symbol: String) {
    var list = load().filter { $0 != symbol }
    list.insert(symbol, at: 0)
    UserDefaults.standard.set(Array(list.prefix(symbolsPerPage)), forKey: key)
  }
}

/// Google Pinyin's symbol keyboard stays open after a symbol is typed.
@MainActor
private func commitSymbol(_ symbol: String) {
  client.resetInput()
  client.commitString(symbol)
  RecentSymbols.add(symbol)
}

private struct SymbolPage: Identifiable {
  let id: Int
  let category: Int  // 0 is recent
  let symbols: [String]
}

struct SymbolView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat

  @State private var page = 1
  @State private var pages = SymbolView.buildPages()

  private static func buildPages() -> [SymbolPage] {
    var pages = [SymbolPage(id: 0, category: 0, symbols: RecentSymbols.load())]
    for (i, category) in googlePinyinSymbolCategories.enumerated() {
      for start in stride(from: 0, to: category.symbols.count, by: symbolsPerPage) {
        let end = min(start + symbolsPerPage, category.symbols.count)
        pages.append(
          SymbolPage(
            id: pages.count, category: i + 1, symbols: Array(category.symbols[start..<end])))
      }
    }
    return pages
  }

  private var currentCategory: Int {
    page < pages.count ? pages[page].category : 1
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let rowHeight = (keyboardHeight - keyboardTopPadding) / 4

    VStack(spacing: 0) {
      // Category tabs replace the toolbar.
      HStack(spacing: 0) {
        ForEach(0...googlePinyinSymbolCategories.count, id: \.self) { i in
          let selected = currentCategory == i
          Group {
            if i == 0 {
              Image(systemName: "clock")
            } else {
              Text(googlePinyinSymbolCategories[i - 1].label)
            }
          }
          .font(.system(size: 17, weight: selected ? .semibold : .regular))
          .foregroundColor(selected ? theme.accentKeyBackgroundColor : theme.altKeyTextColor)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            if let first = pages.firstIndex(where: { $0.category == i }) {
              page = first
            }
          }
        }
      }
      .frame(width: width, height: barHeight)

      TabView(selection: $page) {
        ForEach(pages) { symbolPage in
          SymbolPageView(symbols: symbolPage.symbols, width: width, rowHeight: rowHeight)
            .tag(symbolPage.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(width: width, height: keyboardTopPadding + rowHeight * 3)

      SymbolBottomRow(width: width, height: rowHeight)
    }
    .onAppear {
      // Like Google Pinyin, open on the first page of 常用 every time.
      pages = Self.buildPages()
      page = 1
    }
  }
}

private struct SymbolPageView: View {
  @Environment(\.colorScheme) var colorScheme
  let symbols: [String]
  let width: CGFloat
  let rowHeight: CGFloat

  var body: some View {
    let keyWidth = width / 10
    ZStack(alignment: .topLeading) {
      ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
        let options = googlePinyinSymbolLongPress[symbol] ?? []
        // U+FE0E keeps symbols like ↕ ↩ from rendering as emoji, as in Google Pinyin.
        Text(symbol + "\u{FE0E}")
          .font(.system(size: 20))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .keyTile(
            x: CGFloat(index % 10) * keyWidth,
            y: keyboardTopPadding + CGFloat(index / 10) * rowHeight,
            width: keyWidth, height: rowHeight, variant: .normal, colorScheme: colorScheme,
            action: GestureAction(
              onTap: { commitSymbol(symbol) },
              onLongPress: { index in
                if index >= 0, index < options.count {
                  commitSymbol(options[index])
                }
              }),
            bubbleLabel: symbol, longPressItems: options.map { BubbleItem.text($0) })
      }
      // Google Pinyin: backspace ends the third row, 1.5 keys wide.
      BackspaceView(
        x: keyWidth * 8, y: keyboardTopPadding + rowHeight * 2, width: keyWidth * 1.5,
        height: rowHeight)
    }
    .frame(width: width, height: keyboardTopPadding + rowHeight * 3, alignment: .topLeading)
  }
}

struct SymbolBottomRow: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject private var viewModel = vm
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    let unit = width / 10
    ZStack(alignment: .topLeading) {
      Text(NSLocalizedString("Back", comment: ""))
        .font(.system(size: layoutSwitchFontSize, weight: .bold))
        .keyTile(
          x: 0, y: 0, width: unit * 1.5, height: height, variant: .alternative,
          colorScheme: colorScheme,
          action: GestureAction(onTap: {
            // Back to the letters, or to the candidates when composing.
            vm.setDisplayMode(
              vm.returnMode == .candidates ? .candidates : .initial, resetReturnMode: true)
          }))
      Text("，").font(.system(size: 20))
        .keyTile(
          x: unit * 1.5, y: 0, width: unit, height: height, variant: .alternative,
          colorScheme: colorScheme, action: GestureAction(onTap: { commitSymbol("，") }))
      Text("123")
        .font(.system(size: layoutSwitchFontSize, weight: .bold))
        .keyTile(
          x: unit * 2.5, y: 0, width: unit, height: height, variant: .alternative,
          colorScheme: colorScheme, action: GestureAction(onTap: { vm.setDisplayMode(.numpad) }))
      Image(systemName: "space")
        .keyTile(
          x: unit * 3.5, y: 0, width: unit * 4, height: height, variant: .normal,
          colorScheme: colorScheme,
          action: GestureAction(onTap: {
            client.resetInput()
            client.commitString(" ")
          }))
      Text("。").font(.system(size: 20))
        .keyTile(
          x: unit * 7.5, y: 0, width: unit, height: height, variant: .alternative,
          colorScheme: colorScheme, action: GestureAction(onTap: { commitSymbol("。") }))
      EnterView(
        x: unit * 8.5, y: 0, width: unit * 1.5, height: height,
        returnKeyType: viewModel.returnKeyType, cr: false)
    }
    .frame(width: width, height: height, alignment: .topLeading)
  }
}
