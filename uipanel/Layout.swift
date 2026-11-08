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

enum KeyboardLayouts {
  // TextKeyboard.Layout
  static let text: [[KeyDef]] = [
    [
      alphabet("q", "1"), alphabet("w", "2"), alphabet("e", "3"), alphabet("r", "4"),
      alphabet("t", "5"), alphabet("y", "6"), alphabet("u", "7"), alphabet("i", "8"),
      alphabet("o", "9"), alphabet("p", "0"),
    ],
    [
      alphabet("a", "@"), alphabet("s", "*"), alphabet("d", "+"), alphabet("f", "-"),
      alphabet("g", "="), alphabet("h", "/"), alphabet("j", "#"), alphabet("k", "("),
      alphabet("l", ")"),
    ],
    [
      KeyDef(.caps, width: 0.15, variant: .alternative),
      alphabet("z", "'"), alphabet("x", ":"), alphabet("c", "\""), alphabet("v", "?"),
      alphabet("b", "!"), alphabet("n", "~"), alphabet("m", "\\"),
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
  static let number: [[KeyDef]] = [
    [
      numPad("+", width: 0.15, variant: .alternative),
      numPad("1", width: 0, fontSize: numPadDigitFontSize),
      numPad("2", width: 0, fontSize: numPadDigitFontSize),
      numPad("3", width: 0, fontSize: numPadDigitFontSize),
      numPad("/", width: 0.15, variant: .alternative),
    ],
    [
      numPad("-", width: 0.15, variant: .alternative),
      numPad("4", width: 0, fontSize: numPadDigitFontSize),
      numPad("5", width: 0, fontSize: numPadDigitFontSize),
      numPad("6", width: 0, fontSize: numPadDigitFontSize),
      KeyDef(.miniSpace, width: 0.15, variant: .alternative),
    ],
    [
      numPad("*", width: 0.15, variant: .alternative),
      numPad("7", width: 0, fontSize: numPadDigitFontSize),
      numPad("8", width: 0, fontSize: numPadDigitFontSize),
      numPad("9", width: 0, fontSize: numPadDigitFontSize),
      KeyDef(.backspace, width: 0.15, variant: .alternative),
    ],
    [
      KeyDef(
        .layoutSwitch("ABC", .text), width: 0.15, variant: .alternative,
        fontSize: layoutSwitchFontSize, bold: true),
      numPad(",", width: 0.1, variant: .alternative),
      KeyDef(
        .layoutSwitch("!?#", .symbolPicker), width: 0.13333, variant: .altForeground,
        fontSize: layoutSwitchFontSize, bold: true),
      numPad("0", width: 0.23334, fontSize: numPadDigitFontSize),
      numPad("=", width: 0.13333, variant: .altForeground),
      numPad(".", width: 0.1, variant: .alternative),
      KeyDef(.enter, width: 0.15, variant: .accent),
    ],
  ]
}

/// Long press alternates, from fcitx5-android `PopupPreset.kt`
/// (itself based on fcitx5 `longpress.cpp`).
let popupPreset: [String: [String]] = [
  // Latin
  "q": ["1", "Q"],
  "w": ["2", "W"],
  "e": ["3", "E", "ê", "ë", "ē", "é", "ě", "è", "ė", "ę", "ȩ", "ḝ", "ə"],
  "r": ["4", "R"],
  "t": ["5", "T"],
  "y": ["6", "Y", "ÿ", "ұ", "ү", "ӯ", "ў"],
  "u": ["7", "U", "û", "ü", "ū", "ú", "ǔ", "ù"],
  "i": ["8", "I", "î", "ï", "ī", "í", "ǐ", "ì", "į", "ı"],
  "o": ["9", "O", "ô", "ö", "ō", "ó", "ǒ", "ò", "œ", "ø", "õ"],
  "p": ["0", "P"],
  "a": ["@", "A", "â", "ä", "ā", "á", "ǎ", "à", "æ", "ã", "å"],
  "s": ["*", "S", "ß", "ś", "š", "ş"],
  "d": ["+", "D", "ð"],
  "f": ["-", "F"],
  "g": ["=", "G", "ğ"],
  "h": ["/", "H"],
  "j": ["#", "J"],
  "k": ["(", "[", "{", "K"],
  "l": [")", "]", "}", "L", "ł"],
  "z": ["'", "Z", "`", "ž", "ź", "ż"],
  "x": [":", "X", "×"],
  "c": ["\"", "C", "ç", "ć", "č"],
  "v": ["?", "V", "¿", "ü", "ǖ", "ǘ", "ǚ", "ǜ"],
  "b": ["!", "B", "¡"],
  "n": ["~", "N", "ñ", "ń"],
  "m": ["\\", "M"],
  // Upper case Latin
  "Q": ["1", "q"],
  "W": ["2", "w"],
  "E": ["3", "e", "Ê", "Ë", "Ē", "É", "È", "Ė", "Ę", "Ȩ", "Ḝ", "Ə"],
  "R": ["4", "r"],
  "T": ["5", "t"],
  "Y": ["6", "y", "Ÿ", "Ұ", "Ү", "Ӯ", "Ў"],
  "U": ["7", "u", "Û", "Ü", "Ù", "Ú", "Ū"],
  "I": ["8", "i", "Î", "Ï", "Í", "Ī", "Į", "Ì"],
  "O": ["9", "o", "Ô", "Ö", "Ò", "Ó", "Œ", "Ø", "Ō", "Õ"],
  "P": ["0", "p"],
  "A": ["@", "a", "Â", "Ä", "Ā", "Á", "À", "Æ", "Ã", "Å"],
  "S": ["*", "s", "ẞ", "Ś", "Š", "Ş"],
  "D": ["+", "d", "Ð"],
  "F": ["-", "f"],
  "G": ["=", "g", "Ğ"],
  "H": ["/", "h"],
  "J": ["#", "j"],
  "K": ["(", "k"],
  "L": [")", "l", "Ł"],
  "Z": ["'", "z", "`", "Ž", "Ź", "Ż"],
  "X": [":", "x"],
  "C": ["\"", "c", "Ç", "Ć", "Č"],
  "V": ["?", "v"],
  "B": ["!", "b", "¡"],
  "N": ["~", "n", "Ñ", "Ń"],
  "M": ["\\", "m"],
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
  ".": [",", "?", "!", ":", ";", "_", "%", "$", "^", "&"],
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
