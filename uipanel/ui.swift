import SwiftUI

// Geometry follows fcitx5-android's ThemePrefs / KeyDef defaults (1 dp ≈ 1 pt).

// key_radius: keyCornerRadius in Theme.swift, 2 dp like Google Pinyin or iOS's 8.5 pt.
// fcitx5-android insets every side of a key by the margin, so the gap between
// neighbouring keys is twice the preference value.
let columnGap: CGFloat = 6  // key_horizontal_margin 3 dp
// Google Pinyin 4.5.2: 10 dp gap below each key in portrait, 4 dp in landscape.
let rowGapPortrait: CGFloat = 10
let rowGapLandscape: CGFloat = 4
/// Google Pinyin keyboard body top padding.
let keyboardTopPadding: CGFloat = 6

// KeyDef text sizes.
let keyLabelFontSize: CGFloat = 23
let altLabelFontSize: CGFloat = 10.67  // AltTextKeyView
let layoutSwitchFontSize: CGFloat = 16
let numPadDigitFontSize: CGFloat = 30
let spaceLabelFontSize: CGFloat = 13
let popupFontSize: CGFloat = 23  // PopupEntryUi / PopupKeyUi
let keyIconSize: CGFloat = 24  // Material icon size

// KawaiiBarComponent.HEIGHT
let barHeight: CGFloat = 40
let toolButtonSize: CGFloat = 40
let toolButtonIconSize: CGFloat = 20  // 40 dp button with 10 dp padding

// PreeditUi text is 16 sp; it is shrunk to share the bar with candidates on iOS
// because a keyboard extension cannot float a view above its own frame.
let preeditFontSize: CGFloat = 12
let preeditStripHeight: CGFloat = 14
let candidateFontSize: CGFloat = 20  // CandidateItemUi
let candidateFontSizeWithPreedit: CGFloat = 18
let candidateHorizontalPadding: CGFloat = 10
let candidateVerticalPadding: CGFloat = 4
let candidateGap: CGFloat = 0

let transparent = Color.black.opacity(0.001)

let disabledForeground = Color.gray

/// Name of the keyboard root coordinate space.
let keyboardSpace = "fcitxKeyboard"
