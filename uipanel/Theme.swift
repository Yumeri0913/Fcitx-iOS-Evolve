import SwiftUI

// Color roles mirror fcitx5-android's `Theme` so presets can be copied verbatim
// and both keyboards render the same palette.
struct Theme {
  let name: String
  let isDark: Bool

  let backgroundColor: Color
  let barColor: Color
  let keyboardColor: Color

  let keyBackgroundColor: Color
  let keyTextColor: Color

  let candidateTextColor: Color
  let candidateLabelColor: Color
  let candidateCommentColor: Color

  let altKeyBackgroundColor: Color
  let altKeyTextColor: Color

  let accentKeyBackgroundColor: Color
  let accentKeyTextColor: Color

  let keyPressHighlightColor: Color
  let keyShadowColor: Color

  let popupBackgroundColor: Color
  let popupTextColor: Color

  let spaceBarColor: Color
  let dividerColor: Color
  let clipboardEntryColor: Color

  let genericActiveBackgroundColor: Color
  let genericActiveForegroundColor: Color

  /// Small symbol printed on letter keys.
  let keyHintColor: Color
  /// Key corner radius when the user keeps the theme default.
  let keyRadius: CGFloat

  init(
    name: String, isDark: Bool,
    backgroundColor: UInt32, barColor: UInt32, keyboardColor: UInt32,
    keyBackgroundColor: UInt32, keyTextColor: UInt32,
    candidateTextColor: UInt32, candidateLabelColor: UInt32, candidateCommentColor: UInt32,
    altKeyBackgroundColor: UInt32, altKeyTextColor: UInt32,
    accentKeyBackgroundColor: UInt32, accentKeyTextColor: UInt32,
    keyPressHighlightColor: UInt32, keyShadowColor: UInt32,
    popupBackgroundColor: UInt32, popupTextColor: UInt32,
    spaceBarColor: UInt32, dividerColor: UInt32, clipboardEntryColor: UInt32,
    genericActiveBackgroundColor: UInt32, genericActiveForegroundColor: UInt32,
    keyHintColor: UInt32? = nil, keyRadius: CGFloat = 2
  ) {
    self.name = name
    self.isDark = isDark
    self.backgroundColor = Color(argb: backgroundColor)
    self.barColor = Color(argb: barColor)
    self.keyboardColor = Color(argb: keyboardColor)
    self.keyBackgroundColor = Color(argb: keyBackgroundColor)
    self.keyTextColor = Color(argb: keyTextColor)
    self.candidateTextColor = Color(argb: candidateTextColor)
    self.candidateLabelColor = Color(argb: candidateLabelColor)
    self.candidateCommentColor = Color(argb: candidateCommentColor)
    self.altKeyBackgroundColor = Color(argb: altKeyBackgroundColor)
    self.altKeyTextColor = Color(argb: altKeyTextColor)
    self.accentKeyBackgroundColor = Color(argb: accentKeyBackgroundColor)
    self.accentKeyTextColor = Color(argb: accentKeyTextColor)
    self.keyPressHighlightColor = Color(argb: keyPressHighlightColor)
    self.keyShadowColor = Color(argb: keyShadowColor)
    self.popupBackgroundColor = Color(argb: popupBackgroundColor)
    self.popupTextColor = Color(argb: popupTextColor)
    self.spaceBarColor = Color(argb: spaceBarColor)
    self.dividerColor = Color(argb: dividerColor)
    self.clipboardEntryColor = Color(argb: clipboardEntryColor)
    self.genericActiveBackgroundColor = Color(argb: genericActiveBackgroundColor)
    self.genericActiveForegroundColor = Color(argb: genericActiveForegroundColor)
    self.keyHintColor = Color(argb: keyHintColor ?? altKeyTextColor)
    self.keyRadius = keyRadius
  }
}

extension Color {
  /// 0xAARRGGBB, the literal form used by fcitx5-android's `ThemePreset`.
  init(argb: UInt32) {
    let a = Double((argb >> 24) & 0xff) / 255
    let r = Double((argb >> 16) & 0xff) / 255
    let g = Double((argb >> 8) & 0xff) / 255
    let b = Double(argb & 0xff) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

// Copied from fcitx5-android (InsightKey fork) ThemePreset.kt.
enum ThemePreset {
  // Google Pinyin 4.x default skin "Material Light" with key borders off,
  // from its style_sheet_material_light.
  static let googlePinyinLight = Theme(
    name: "GooglePinyinLight", isDark: false,
    backgroundColor: 0xffec_eff1, barColor: 0xffe4_e7e9, keyboardColor: 0xffec_eff1,
    keyBackgroundColor: 0xfffb_fbfc, keyTextColor: 0xff37_474f,
    candidateTextColor: 0xff37_474f, candidateLabelColor: 0xff37_474f,
    candidateCommentColor: 0xb337_474f,
    altKeyBackgroundColor: 0xffdf_e2e4, altKeyTextColor: 0xb337_474f,
    accentKeyBackgroundColor: 0xff4d_b6ac, accentKeyTextColor: 0xffff_ffff,
    keyPressHighlightColor: 0x1937_474f, keyShadowColor: 0xffc0_c3c4,
    popupBackgroundColor: 0xffd9_dbdd, popupTextColor: 0xff37_474f,
    spaceBarColor: 0x3337_474f, dividerColor: 0x3337_474f, clipboardEntryColor: 0xfffb_fbfc,
    genericActiveBackgroundColor: 0xff80_cbc4, genericActiveForegroundColor: 0xff37_474f)

  // Google Pinyin 4.x "Material Dark", key borders off.
  static let googlePinyinDark = Theme(
    name: "GooglePinyinDark", isDark: true,
    backgroundColor: 0xff26_3238, barColor: 0xff21_272b, keyboardColor: 0xff26_3238,
    keyBackgroundColor: 0xff40_4a50, keyTextColor: 0xccff_ffff,
    candidateTextColor: 0xccff_ffff, candidateLabelColor: 0xccff_ffff,
    candidateCommentColor: 0x99ff_ffff,
    altKeyBackgroundColor: 0xff31_3c42, altKeyTextColor: 0x99ff_ffff,
    accentKeyBackgroundColor: 0xff80_cbc4, accentKeyTextColor: 0xffff_ffff,
    keyPressHighlightColor: 0x1aff_ffff, keyShadowColor: 0xff1f_292e,
    popupBackgroundColor: 0xff3c_474c, popupTextColor: 0xffff_ffff,
    spaceBarColor: 0x1aff_ffff, dividerColor: 0x1aff_ffff, clipboardEntryColor: 0xff40_4a50,
    genericActiveBackgroundColor: 0xff4d_b6ac, genericActiveForegroundColor: 0xffff_ffff)
}

extension ThemePreset {
  // The iOS 26 system keyboard, measured on the simulator: a transparent background
  // lets the system's translucent keyboard backdrop show through; all keys share one
  // fill without shadow and have about 8.5 pt corners. The return key is only blue
  // for actions like search or send.
  static let iosLight = Theme(
    name: "iOSLight", isDark: false,
    backgroundColor: 0x0100_0000, barColor: 0x0100_0000, keyboardColor: 0x0100_0000,
    keyBackgroundColor: 0xffff_ffff, keyTextColor: 0xff00_0000,
    candidateTextColor: 0xff00_0000, candidateLabelColor: 0xff00_0000,
    candidateCommentColor: 0xff8e_8e93,
    altKeyBackgroundColor: 0xffff_ffff, altKeyTextColor: 0xff00_0000,
    accentKeyBackgroundColor: 0xff00_7aff, accentKeyTextColor: 0xffff_ffff,
    keyPressHighlightColor: 0x2600_0000, keyShadowColor: 0x0000_0000,
    popupBackgroundColor: 0xffff_ffff, popupTextColor: 0xff00_0000,
    spaceBarColor: 0xffff_ffff, dividerColor: 0x2600_0000, clipboardEntryColor: 0xffff_ffff,
    genericActiveBackgroundColor: 0xff00_7aff, genericActiveForegroundColor: 0xffff_ffff,
    keyHintColor: 0xff8e_8e93, keyRadius: 8.5)

  static let iosDark = Theme(
    name: "iOSDark", isDark: true,
    backgroundColor: 0x0100_0000, barColor: 0x0100_0000, keyboardColor: 0x0100_0000,
    keyBackgroundColor: 0xff60_6061, keyTextColor: 0xffff_ffff,
    candidateTextColor: 0xffff_ffff, candidateLabelColor: 0xffff_ffff,
    candidateCommentColor: 0xff98_989f,
    altKeyBackgroundColor: 0xff60_6061, altKeyTextColor: 0xffff_ffff,
    accentKeyBackgroundColor: 0xff0a_84ff, accentKeyTextColor: 0xffff_ffff,
    keyPressHighlightColor: 0x33ff_ffff, keyShadowColor: 0x0000_0000,
    popupBackgroundColor: 0xff60_6061, popupTextColor: 0xffff_ffff,
    spaceBarColor: 0xff60_6061, dividerColor: 0x33ff_ffff, clipboardEntryColor: 0xff60_6061,
    genericActiveBackgroundColor: 0xff0a_84ff, genericActiveForegroundColor: 0xffff_ffff,
    keyHintColor: 0xff98_989f, keyRadius: 8.5)
}

// Same values and order as the uipanel addon's ThemeStyle option.
enum ThemeStyle: Int {
  case ios = 0
  case googlePinyin = 1
}

// Same values and order as the uipanel addon's KeyBorder option.
enum KeyBorderMode: Int {
  case followThemeStyle = 0
  case on = 1
  case off = 2

  func resolve(_ style: ThemeStyle) -> Bool {
    switch self {
    case .followThemeStyle: return style == .ios
    case .on: return true
    case .off: return false
    }
  }
}

// Set from the addon config on the main thread before views read them.
nonisolated(unsafe) var themeStyle = ThemeStyle.ios
/// User key radius in pt, or negative to use the theme's.
nonisolated(unsafe) var keyRadiusSetting = -1
/// Google Pinyin's 智能更正: send touch alternatives with letter presses.
nonisolated(unsafe) var touchCorrectionEnabled = true
// Google Pinyin keyboard settings, see uipanel.h.
nonisolated(unsafe) var doubleSpacePeriodEnabled = true
nonisolated(unsafe) var keyPopupEnabled = true
nonisolated(unsafe) var longPressDelaySetting: TimeInterval = 0.3
/// Swipe distance ratio: 3.0 (low) .. 0.5 (high sensitivity).
nonisolated(unsafe) var slideDistanceRatio: CGFloat = 1
/// Google Pinyin height ratio, 0.9 ... 1.1.
nonisolated(unsafe) var heightRatioSetting: CGFloat = 1

// Google Pinyin skins: light, dark, or follow the system appearance.
// Matches the `Theme` option of the uipanel addon config.
enum ThemeMode: Int {
  case followSystem = 0
  case light = 1
  case dark = 2

  func resolve(_ system: ColorScheme) -> ColorScheme {
    switch self {
    case .followSystem:
      return system
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

func currentTheme(_ colorScheme: ColorScheme) -> Theme {
  switch themeStyle {
  case .ios:
    return colorScheme == .dark ? ThemePreset.iosDark : ThemePreset.iosLight
  case .googlePinyin:
    return colorScheme == .dark ? ThemePreset.googlePinyinDark : ThemePreset.googlePinyinLight
  }
}

var keyCornerRadius: CGFloat {
  keyRadiusSetting >= 0 ? CGFloat(keyRadiusSetting) : currentTheme(.light).keyRadius
}

// Google Pinyin "按键边框": bordered key tiles with a bottom shadow.
// Off (Google Pinyin's default) draws flat labels on the keyboard background.
struct KeyBorderKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var keyBorder: Bool {
    get { self[KeyBorderKey.self] }
    set { self[KeyBorderKey.self] = newValue }
  }
}

// Convenience accessors kept for views that only need a color role.
func getBackground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).backgroundColor
}

func getNormalBackground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).keyBackgroundColor
}

func getFunctionBackground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).altKeyBackgroundColor
}

func getNormalForeground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).keyTextColor
}

func getAltForeground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).altKeyTextColor
}

func getShadow(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).keyShadowColor
}

func getPressHighlight(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).keyPressHighlightColor
}

func getHighlightBackground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).keyPressHighlightColor
}

func getAccentBackground(_ colorScheme: ColorScheme) -> Color {
  return currentTheme(colorScheme).accentKeyBackgroundColor
}

func getDisabledForeground(_ colorScheme: ColorScheme) -> Color {
  // Android's disabledAlpha.
  return currentTheme(colorScheme).altKeyTextColor.opacity(0.38)
}
