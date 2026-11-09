import SwiftUI

// Key definitions ported from fcitx5-android `KeyDef.kt` / `KeyDefPreset.kt`.
// Percent widths are fractions of the row; 0 means fill the remaining space.

enum KeyVariant {
  case normal  // key background, key text
  case altForeground  // key background, alt text (globe)
  case alternative  // alt background, alt text (caps, backspace, ?123, , .)
  case accent  // accent background (return)
}

enum LayoutTarget {
  case text
  case number
  case symbolPicker
}

enum KeyKind {
  /// Letter with a punctuation shown as alt label, input by swipe or long press.
  case alphabet(String, alt: String)
  /// Punctuation key; long press shows alternates from `PopupPreset`.
  case symbol(String)
  /// Comma with emoji / quick phrase / unicode menu.
  case comma
  case caps
  case backspace
  case layoutSwitch(String, LayoutTarget)
  case globe
  case space
  case enter
  /// Number keyboard key: committed directly, no popup.
  case numPad(String, code: String)
  case miniSpace
  /// Empty room for a view laid over it, like the number keyboard's side panel.
  case blank
}

struct KeyDef {
  let kind: KeyKind
  let percentWidth: CGFloat
  let variant: KeyVariant
  let fontSize: CGFloat
  let bold: Bool

  init(
    _ kind: KeyKind, width: CGFloat = 0.1, variant: KeyVariant = .normal,
    fontSize: CGFloat = keyLabelFontSize, bold: Bool = false
  ) {
    self.kind = kind
    self.percentWidth = width
    self.variant = variant
    self.fontSize = fontSize
    self.bold = bold
  }
}

private func alphabet(_ letter: String, _ alt: String) -> KeyDef {
  KeyDef(.alphabet(letter, alt: alt))
}

private func numPad(
  _ label: String, width: CGFloat, variant: KeyVariant = .normal,
  fontSize: CGFloat = keyLabelFontSize
) -> KeyDef {
  let code = label.count == 1 && label.first!.isNumber ? "Numpad\(label)" : ""
  return KeyDef(.numPad(label, code: code), width: width, variant: variant, fontSize: fontSize)
}

/// Google Pinyin digit keyboard side columns, 149 of 1000.
let numberSideWidth: CGFloat = 0.149
/// Google Pinyin digit keyboard left panel, four shown at a time.
let numberSidePanel = ["+", "-", "*", "/", "(", ")"]
let numberSidePanelVisible = 4

enum KeyboardLayouts {
  // TextKeyboard.Layout with Google Pinyin 4.5.2's key symbols (typed by swiping up)
  // (softkeys_input_zh_pinyin_qwerty.xml).
  static let text: [[KeyDef]] = [
    [
      alphabet("q", "1"), alphabet("w", "2"), alphabet("e", "3"), alphabet("r", "4"),
      alphabet("t", "5"), alphabet("y", "6"), alphabet("u", "7"), alphabet("i", "8"),
      alphabet("o", "9"), alphabet("p", "0"),
    ],
    [
      alphabet("a", "@"), alphabet("s", "*"), alphabet("d", "+"), alphabet("f", "-"),
      alphabet("g", "="), alphabet("h", "/"), alphabet("j", "#"), alphabet("k", "（"),
      alphabet("l", "）"),
    ],
    [
      KeyDef(.caps, width: 0.15, variant: .alternative),
      alphabet("z", "、"), alphabet("x", "："), alphabet("c", "\""), alphabet("v", "？"),
      alphabet("b", "！"), alphabet("n", "～"), alphabet("m", "."),
      KeyDef(.backspace, width: 0.15, variant: .alternative),
    ],
    [
      KeyDef(
        .layoutSwitch("?123", .number), width: 0.15, variant: .alternative,
        fontSize: layoutSwitchFontSize, bold: true),
      KeyDef(.comma, width: 0.1, variant: .alternative),
      KeyDef(.globe, width: 0.1, variant: .altForeground),
      KeyDef(.space, width: 0, fontSize: spaceLabelFontSize),
      KeyDef(.symbol("."), width: 0.1, variant: .alternative),
      KeyDef(.enter, width: 0.15, variant: .accent),
    ],
  ]

  // NumberKeyboard.Layout
  /// Google Pinyin 4.x digit keyboard (keyboard_non_prime_digit): a scrollable column of
  /// `numberSidePanel` on the left (laid over the blank keys, see NumpadView), 1-9, and # space
  /// backspace on the right. Columns weigh 149/702/149 like Google's.
  static let number: [[KeyDef]] = [
    [
      KeyDef(.blank, width: numberSideWidth),
      numPad("1", width: 0, fontSize: numPadDigitFontSize),
      numPad("2", width: 0, fontSize: numPadDigitFontSize),
      numPad("3", width: 0, fontSize: numPadDigitFontSize),
      numPad("#", width: numberSideWidth, variant: .alternative),
    ],
    [
      KeyDef(.blank, width: numberSideWidth),
      numPad("4", width: 0, fontSize: numPadDigitFontSize),
      numPad("5", width: 0, fontSize: numPadDigitFontSize),
      numPad("6", width: 0, fontSize: numPadDigitFontSize),
      KeyDef(.miniSpace, width: numberSideWidth, variant: .alternative),
    ],
    [
      KeyDef(.blank, width: numberSideWidth),
      numPad("7", width: 0, fontSize: numPadDigitFontSize),
      numPad("8", width: 0, fontSize: numPadDigitFontSize),
      numPad("9", width: 0, fontSize: numPadDigitFontSize),
      KeyDef(.backspace, width: numberSideWidth, variant: .alternative),
    ],
    [
      KeyDef(
        .layoutSwitch("ABC", .text), width: 0.15, variant: .alternative,
        fontSize: layoutSwitchFontSize, bold: true),
      numPad(",", width: 0.1, variant: .alternative),
      // Google Pinyin digit keyboard bottom row: 150/100/100/300/100/100/150.
      KeyDef(
        .layoutSwitch("@?#", .symbolPicker), width: 0.1, variant: .altForeground,
        fontSize: layoutSwitchFontSize, bold: true),
      numPad("0", width: 0.3, fontSize: numPadDigitFontSize),
      numPad("=", width: 0.1, variant: .altForeground),
      numPad(".", width: 0.1, variant: .alternative),
      KeyDef(.enter, width: 0.15, variant: .accent),
    ],
  ]
}

/// Long press alternates: letters and the period follow Google Pinyin, the rest
/// fcitx5-android `PopupPreset.kt` (itself based on fcitx5 `longpress.cpp`).
let popupPreset: [String: [String]] = [
  // Google Pinyin long press: key symbol, lower case, upper case, tones.
  "q": ["1", "q", "Q"],
  "w": ["2", "w", "W"],
  "e": ["3", "e", "E", "ê", "ē", "é", "ě", "è"],
  "r": ["4", "r", "R"],
  "t": ["5", "t", "T"],
  "y": ["6", "y", "Y"],
  "u": ["7", "u", "U", "ū", "ú", "ǔ", "ù"],
  "i": ["8", "i", "I", "ī", "í", "ǐ", "ì"],
  "o": ["9", "o", "O", "ō", "ó", "ǒ", "ò"],
  "p": ["0", "p", "P"],
  "a": ["@", "a", "A", "ā", "á", "ǎ", "à"],
  "s": ["*", "s", "S"],
  "d": ["+", "d", "D"],
  "f": ["-", "f", "F"],
  "g": ["=", "g", "G"],
  "h": ["/", "h", "H"],
  "j": ["#", "j", "J"],
  "k": ["（", "k", "K"],
  "l": ["）", "l", "L"],
  "z": ["、", "z", "Z"],
  "x": ["：", "x", "X"],
  "c": ["\"", "c", "C"],
  "v": ["？", "v", "V", "ü", "ǖ", "ǘ", "ǚ", "ǜ"],
  "b": ["！", "b", "B"],
  "n": ["～", "n", "N"],
  "m": [".", "m", "M"],
  // Upper case: symbol and lower case.
  "Q": ["1", "q"],
  "W": ["2", "w"],
  "E": ["3", "e"],
  "R": ["4", "r"],
  "T": ["5", "t"],
  "Y": ["6", "y"],
  "U": ["7", "u"],
  "I": ["8", "i"],
  "O": ["9", "o"],
  "P": ["0", "p"],
  "A": ["@", "a"],
  "S": ["*", "s"],
  "D": ["+", "d"],
  "F": ["-", "f"],
  "G": ["=", "g"],
  "H": ["/", "h"],
  "J": ["#", "j"],
  "K": ["（", "k"],
  "L": ["）", "l"],
  "Z": ["、", "z"],
  "X": ["：", "x"],
  "C": ["\"", "c"],
  "V": ["？", "v"],
  "B": ["！", "b"],
  "N": ["～", "n"],
  "M": [".", "m"],
  // Numbers
  "0": ["∅", "ⁿ", "⁰"],
  "1": ["¹", "½", "⅓", "¼", "⅕", "⅙", "⅐", "⅛", "⅑", "⅒"],
  "2": ["²", "⅖", "⅔"],
  "3": ["³", "⅗", "¾", "⅜"],
  "4": ["⁴", "⅘", "⅝", "⅚"],
  "5": ["⁵", "⅝", "⅚"],
  "6": ["⁶"],
  "7": ["⁷", "⅞"],
  "8": ["⁸"],
  "9": ["⁹"],
  // Punctuation
  // Google Pinyin period key (softkey_bottom_sentence_zh_popup_punctuation).
  ".": ["…", "？", "！", "：", "；", "_", "%", "$", "^", "&", ":P", ":D", ":(", ":)", "^_^"],
  "-": ["—", "–", "·"],
  "?": ["¿", "‽"],
  "'": ["‘", "’", "‚", "›", "‹"],
  "!": ["¡"],
  "\"": ["“", "”", "„", "»", "«"],
  "/": ["÷"],
  "#": ["№"],
  "%": ["‰", "℅"],
  "^": ["↑", "↓", "←", "→"],
  "+": ["±"],
  "<": ["≤", "«", "‹", "⟨"],
  "=": ["∞", "≠", "≈"],
  ">": ["≥", "»", "›", "⟩"],
  "°": ["′", "″", "‴"],
  // Currency
  "$": ["¢", "€", "£", "¥", "₹", "₽", "₺", "₩", "₱", "₿"],
]

/// Maximum cells per row in a long press popup, as fcitx5-android `PopupKeyboardUi`.
let popupColumnLimit = 5

func popupColumns(_ count: Int) -> Int {
  // rowCount = ceil(count / 5); columnCount = round(count / rowCount)
  if count <= 0 {
    return 1
  }
  let rows = Int(ceil(Double(count) / Double(popupColumnLimit)))
  return max(1, Int((Double(count) / Double(rows)).rounded()))
}

func popupRows(_ count: Int) -> Int {
  let columns = popupColumns(count)
  return max(1, Int(ceil(Double(count) / Double(columns))))
}

/// Left edge of a popup grid so that the preferred column sits over the key at `x`,
/// shifted to stay inside the keyboard like `calcInitialFocusedColumn`.
func popupLeft(
  keyCenterX x: CGFloat, cellWidth: CGFloat, columns: Int, preferredColumn: Int,
  keyboardWidth: CGFloat
) -> CGFloat {
  let column = CGFloat(max(0, min(preferredColumn, columns - 1)))
  let total = cellWidth * CGFloat(columns)
  let left = x - cellWidth / 2 - column * cellWidth
  return max(0, min(left, keyboardWidth - total))
}

/// Column over the key after `popupLeft` clamping.
func popupAnchorColumn(
  keyCenterX x: CGFloat, cellWidth: CGFloat, columns: Int, preferredColumn: Int,
  keyboardWidth: CGFloat
) -> Int {
  let left = popupLeft(
    keyCenterX: x, cellWidth: cellWidth, columns: columns, preferredColumn: preferredColumn,
    keyboardWidth: keyboardWidth)
  let column = Int(((x - cellWidth / 2 - left) / cellWidth).rounded())
  return max(0, min(column, columns - 1))
}
