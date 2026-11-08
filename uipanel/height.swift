import SwiftUI

struct TotalHeightKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
  var totalHeight: CGFloat {
    get { self[TotalHeightKey.self] }
    set { self[TotalHeightKey.self] = newValue }
  }
}

enum KeyboardState {
  case portrait
  case landscape
  case floating
}

@MainActor
private var isFloating = false

@MainActor
func setFloating(_ width: CGFloat) {
  isFloating =
    (UIScreen.main.bounds.width >= 1000 || UIScreen.main.bounds.height > 1000)
    && width < UIScreen.main.bounds.width && width < UIScreen.main.bounds.height
}

@MainActor
func getKeyboardState() -> KeyboardState {
  if isFloating {
    return .floating
  }
  if UIScreen.main.bounds.width < UIScreen.main.bounds.height {
    return .portrait
  }
  return .landscape
}

// Percent mode: fcitx5-android keyboard_height_percent defaults (InsightKey fork:
// 27% portrait, upstream 49% landscape). The key area is this fraction of the screen height and
// the 40 dp bar is added on top.
let phoneKeyboardHeightPercentPortrait: CGFloat = 0.27
let phoneKeyboardHeightPercentLandscape: CGFloat = 0.49

// Same values and order as the uipanel addon's HeightMode option.
enum KeyboardHeightMode: Int {
  case googlePinyin = 0
  case percent = 1
}

@MainActor
var keyboardHeightMode = KeyboardHeightMode.googlePinyin

/// Google Pinyin 4.x `keyboard_body_height` (from its 4.5.2 dimens.xml): the key
/// area below its 40 dp candidate bar, by smallest screen width bucket. Ported from
/// InsightKey's `KeyboardHeightMode.googlePinyinBodyHeightDp`.
func googlePinyinBodyHeight(smallestScreenWidth: CGFloat, landscape: Bool) -> CGFloat {
  if landscape {
    if smallestScreenWidth >= 768 { return 328 }  // values-sw768dp-land
    if smallestScreenWidth >= 600 { return 241 }  // values-sw600dp-land
    if smallestScreenWidth >= 400 { return 176 }  // values-sw400dp-land
    return 162  // values-land
  }
  if smallestScreenWidth >= 600 { return 287 }  // values-sw600dp
  if smallestScreenWidth >= 400 { return 242 }  // values-sw400dp
  return 209  // values
}

@MainActor
func getDefaultTotalHeight() -> CGFloat {
  let state = getKeyboardState()
  if keyboardHeightMode == .googlePinyin && state != .floating {
    let bounds = UIScreen.main.bounds
    return googlePinyinBodyHeight(
      smallestScreenWidth: min(bounds.width, bounds.height), landscape: state == .landscape)
      + barHeight
  }
  switch state {
  case .portrait:
    let height = UIScreen.main.bounds.height
    if height < 1000 {
      // iPhone: match fcitx5-android's percentage keyboard height.
      return (height * phoneKeyboardHeightPercentPortrait).rounded() + barHeight
    } else if height < 1150 {
      return 260
    } else if height < 1200 {
      // Older 11-inch Pros are shorter than 1200 pt but keep the Pro keyboard size.
      return UIScreen.main.bounds.width >= 834 ? 260 : 255
    } else if height < 1300 {
      return 260
    }
    return 325
  case .landscape:
    let height = UIScreen.main.bounds.width
    if height < 1000 {
      // iPhone: landscape screen height is the short side.
      return (UIScreen.main.bounds.height * phoneKeyboardHeightPercentLandscape).rounded()
        + barHeight
    } else if height < 1150 {
      // The 10.5-inch Air uses the compact landscape keyboard.
      return UIScreen.main.bounds.height >= 834 ? 342 : 348
    } else if height < 1200 {
      return UIScreen.main.bounds.height >= 834 ? 348 : 342
    } else if height < 1300 {
      return 348
    }
    return 420
  case .floating:
    return 255
  }
}

/// Vertical gap between key tiles for the current orientation.
@MainActor
var rowGap: CGFloat {
  return getKeyboardState() == .landscape ? rowGapLandscape : rowGapPortrait
}

@MainActor
func getKeyLabelFontSize(_ rowHeight: CGFloat) -> CGFloat {
  // fcitx5-android uses a fixed 23 dp; only unusually short rows shrink.
  return min(rowHeight * 0.7, keyLabelFontSize)
}

func getKeyboardHeight(_ totalHeight: CGFloat) -> CGFloat {
  return totalHeight - barHeight
}

func getBarHeight(_ totalHeight: CGFloat) -> CGFloat {
  return barHeight
}
