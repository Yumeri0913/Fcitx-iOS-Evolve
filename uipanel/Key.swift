import SwiftUI
import SwiftUtil

let keyRepeatInterval = 0.08

// Key tile colors by fcitx5-android `KeyDef.Appearance.Variant`.
func keyBackground(_ variant: KeyVariant, _ theme: Theme) -> Color {
  switch variant {
  case .normal, .altForeground:
    return theme.keyBackgroundColor
  case .alternative:
    return theme.altKeyBackgroundColor
  case .accent:
    return theme.accentKeyBackgroundColor
  }
}

func keyForeground(_ variant: KeyVariant, _ theme: Theme) -> Color {
  switch variant {
  case .normal:
    return theme.keyTextColor
  case .altForeground, .alternative:
    return theme.altKeyTextColor
  case .accent:
    return theme.accentKeyTextColor
  }
}

func adjustFontSize(_ text: String, _ fontSize: CGFloat, _ widthLimit: CGFloat) -> CGFloat {
  let textWidth = getTextWidth(text, fontSize)
  return textWidth <= widthLimit ? fontSize : fontSize * widthLimit / textWidth
}

/// Material icons are 24 dp; shrink only when the tile is too short.
@MainActor
func keyIconHeight(_ height: CGFloat) -> CGFloat {
  return min(keyIconSize, (height - rowGap) * 0.55)
}

/// Text input from the letter keyboard. English mode bypasses the input method
/// and commits the key as is, like fcitx5-android's inactive keyboard-us.
@MainActor
func typeKey(_ key: String, _ code: String) {
  if vm.englishMode {
    client.forwardKey(key, code)
  } else {
    client.keyPressed(key, code)
  }
}

@MainActor
func performPopupItem(_ item: BubbleItem) {
  switch item.type {
  case "unicode":
    client.resetInput()
    client.triggerUnicode()
  case "quickphrase":
    client.resetInput()
    client.triggerQuickPhrase()
  case "emoji":
    // No emoji picker yet; the symbol picker is the closest window.
    vm.setDisplayMode(.symbol)
  case nil:
    if let label = item.label {
      vm.resetLayerIfNotLocked()
      typeKey(label, "")
    }
  default:
    FCITX_ERROR("Unknown popup item type: \(item.type ?? "")")
  }
}

extension View {
  /// Apply key geometry, gestures and theme colors for a variant.
  @MainActor
  func keyTile(
    x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
    variant: KeyVariant, colorScheme: ColorScheme, action: GestureAction,
    hMargin: CGFloat = columnGap, vMargin: CGFloat? = nil, radius: CGFloat = keyCornerRadius,
    pressedView: (any View)? = nil, bubbleLabel: String? = nil, swipeLabel: String? = nil,
    swipeUpLabel: String? = nil,
    longPressItems: [BubbleItem]? = nil, longPressIndex: Int? = nil,
    bubbleFontSize: CGFloat? = nil, disable: Bool = false
  ) -> some View {
    let theme = currentTheme(colorScheme)
    return keyProperties(
      x: x, y: y, width: width, height: height, hMargin: hMargin, vMargin: vMargin,
      radius: radius,
      background: keyBackground(variant, theme),
      foreground: keyForeground(variant, theme),
      highlight: theme.keyPressHighlightColor,
      shadow: theme.keyShadowColor,
      action: action, pressedView: pressedView, bubbleLabel: bubbleLabel,
      swipeLabel: swipeLabel, swipeUpLabel: swipeUpLabel, longPressItems: longPressItems,
      longPressIndex: longPressIndex,
      bubbleFontSize: bubbleFontSize, disable: disable)
  }
}

/// fcitx5-android `AlphabetKey` with Google Pinyin's gestures: swipe down inputs the
/// symbol printed on the key, swipe up commits the letter itself, long press shows
/// `popupPreset` alternates.
struct AlphabetKeyView: View {
  @ObservedObject private var viewModel = vm
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let letter: String
  let alt: String
  let shifted: Bool

  private var displayLetter: String {
    shifted ? letter.uppercased() : letter.lowercased()
  }

  /// Google Pinyin's URL and email keyboards put , and _ on z and m.
  private var symbol: String {
    guard viewModel.urlOrEmail else { return alt }
    switch letter.lowercased() {
    case "z": return ","
    case "m": return "_"
    default: return alt
    }
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    let letter = displayLetter
    let alt = symbol
    // The first long press item is the slide-down symbol.
    let alternates = [alt] + (popupPreset[letter] ?? []).dropFirst()
    let items = alternates.map { BubbleItem.text($0) }
    let fontSize = getKeyLabelFontSize(height)
    let altText = Text(alt)
      .font(.system(size: altLabelFontSize, weight: .bold))
      .foregroundColor(theme.keyHintColor)
    let landscape = getKeyboardState() == .landscape

    Group {
      if landscape {
        // ThemePrefs.PunctuationPosition: top right in landscape.
        ZStack(alignment: .topTrailing) {
          Text(letter).font(.system(size: fontSize))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          altText.padding(.trailing, 4)
        }
      } else {
        // Bottom in portrait: the letter is raised and the punctuation sits below it.
        VStack(spacing: 0) {
          Text(letter).font(.system(size: fontSize))
            .frame(maxHeight: .infinity)
          altText.padding(.bottom, 2)
        }
      }
    }
    .keyTile(
      x: x, y: y, width: width, height: height, variant: .normal, colorScheme: colorScheme,
      action: GestureAction(
        onOrderedKeyPress: {
          return {
            vm.resetLayerIfNotLocked()
            typeKey(letter, "Key\(self.letter.uppercased())")
          }
        },
        onLongPress: { index in
          if index >= 0, index < items.count {
            performPopupItem(items[index])
          }
        },
        onSwipe: { direction in
          switch direction {
          case .down:
            vm.resetLayerIfNotLocked()
            typeKey(alt, "")
          case .up:
            vm.resetLayerIfNotLocked()
            if viewModel.hasPreedit {
              typeKey(letter, "Key\(self.letter.uppercased())")
            } else {
              // Commit the letter as is, even in Chinese mode.
              client.forwardKey(letter, "")
            }
          default:
            break
          }
        }
      ),
      bubbleLabel: letter, swipeLabel: alt, swipeUpLabel: letter, longPressItems: items,
      longPressIndex: 0)
  }
}

/// fcitx5-android `SymbolKey`.
struct SymbolKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let symbol: String
  let variant: KeyVariant

  var body: some View {
    let items = (popupPreset[symbol] ?? []).map { BubbleItem.text($0) }
    Text(symbol)
      .font(.system(size: getKeyLabelFontSize(height)))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onOrderedKeyPress: {
            return {
              vm.resetLayerIfNotLocked()
              typeKey(symbol, "")
            }
          },
          onLongPress: { index in
            if index >= 0, index < items.count {
              performPopupItem(items[index])
            }
          }
        ),
        bubbleLabel: symbol, longPressItems: items, longPressIndex: 0)
  }
}

/// fcitx5-android `CommaKey`: comma with an emoji badge and a
/// Emoji / QuickPhrase / Unicode long press menu.
struct CommaKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  let variant: KeyVariant

  private let items = [
    BubbleItem(label: nil, type: "emoji"),
    BubbleItem(label: nil, type: "quickphrase"),
    BubbleItem(label: nil, type: "unicode"),
  ]

  var body: some View {
    VStack(spacing: 0) {
      Image(systemName: "face.smiling")
        .font(.system(size: 13))
        .padding(.top, 4)
      Spacer(minLength: 0)
      Text(",").font(.system(size: getKeyLabelFontSize(height)))
        .padding(.bottom, 4)
    }
    .keyTile(
      x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
      action: GestureAction(
        onOrderedKeyPress: {
          return {
            vm.resetLayerIfNotLocked()
            typeKey(",", "Comma")
          }
        },
        onLongPress: { index in
          if index >= 0, index < items.count {
            performPopupItem(items[index])
          }
        }
      ),
      bubbleLabel: ",", longPressItems: items, longPressIndex: 0)
  }
}

/// fcitx5-android `LayoutSwitchKey` ("?123", "ABC", "!?#").
struct LayoutSwitchKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String
  let target: LayoutTarget
  let variant: KeyVariant
  let fontSize: CGFloat

  var body: some View {
    Text(label)
      .font(.system(size: fontSize, weight: .bold))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            switch target {
            case .text:
              vm.setDisplayMode(.initial, resetReturnMode: true)
            case .number:
              vm.setDisplayMode(.numpad)
            case .symbolPicker:
              vm.setDisplayMode(.symbol)
            }
          }
        ))
  }
}

struct SpaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String
  let forward: Bool

  var body: some View {
    Text(label)
      .font(.system(size: spaceLabelFontSize))
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .padding(.horizontal, 4)
      .keyTile(
        x: x, y: y, width: width, height: height, variant: .normal, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            vm.resetLayerIfNotLocked()
            if forward {
              client.resetInput()
              client.forwardKey(" ", "")
            } else {
              typeKey(" ", "")
            }
          },
          onLongPress: { _ in
            showInputMethodPicker(CGRect(x: x, y: y + barHeight, width: width, height: height))
          },
          onSlide: { step in
            if step > 0 {
              for _ in 0..<step {
                client.keyPressed("", "ArrowRight")
              }
            } else {
              for _ in 0..<(-step) {
                client.keyPressed("", "ArrowLeft")
              }
            }
          }
        )
      )
  }
}

/// fcitx5-android `MiniSpaceKey` on the number keyboard.
struct MiniSpaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  let variant: KeyVariant

  var body: some View {
    Text("⎵")
      .font(.system(size: getKeyLabelFontSize(height)))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            vm.resetLayerIfNotLocked()
            client.resetInput()
            client.forwardKey(" ", "")
          }
        ))
  }
}

/// fcitx5-android `NumPadKey`: committed directly, no popup.
struct NumPadKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let label: String
  let code: String
  let variant: KeyVariant
  let fontSize: CGFloat

  var body: some View {
    Text(label)
      .font(.system(size: min(fontSize, height * 0.7)))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            vm.resetLayerIfNotLocked()
            client.resetInput()
            client.forwardKey(label, code)
          }
        ))
  }
}

struct BackspaceView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  var variant: KeyVariant = .alternative
  var hMargin: CGFloat? = nil
  var vMargin: CGFloat? = nil
  var radius: CGFloat? = nil

  @State private var deleteTimer: Timer? = nil

  func startDelete() {
    stopDelete()
    deleteTimer = Timer.scheduledTimer(withTimeInterval: keyRepeatInterval, repeats: true) { _ in
      Task { @MainActor in
        vm.resetLayerIfNotLocked()
        client.keyPressed("", "Backspace")
      }
    }
  }

  func stopDelete() {
    deleteTimer?.invalidate()
    deleteTimer = nil
  }

  var body: some View {
    let iconHeight = keyIconHeight(height)
    Image(systemName: "delete.left")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: iconHeight)
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            vm.resetLayerIfNotLocked()
            client.keyPressed("", "Backspace")
          },
          onLongPress: { _ in
            startDelete()
          },
          onSlide: { step in
            vm.slideBackspace(step)
          },
          onRelease: {
            stopDelete()
          }
        ),
        hMargin: hMargin ?? columnGap, vMargin: vMargin, radius: radius ?? keyCornerRadius,
        pressedView: Image(systemName: "delete.left.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: iconHeight)
      )
      .onDisappear {
        stopDelete()
      }
  }
}

/// fcitx5-android `LanguageKey`.
struct GlobeView: View {
  @Environment(\.colorScheme) var colorScheme

  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Image(systemName: "globe")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: keyIconHeight(height))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: .altForeground,
        colorScheme: colorScheme,
        // Like the InsightKey globe key: only toggles Chinese / English, never
        // switches to other input methods (long press space for that).
        action: GestureAction(onTap: { vm.toggleEnglishMode() })
      )
  }
}

/// Icon for the return key, after fcitx5-android `ReturnKeyDrawableComponent`.
func returnKeySymbol(_ type: UIReturnKeyType?) -> String {
  switch type {
  case .go:
    return "arrow.right"
  case .search, .google, .yahoo:
    return "magnifyingglass"
  case .send:
    return "paperplane.fill"
  case .next, .continue:
    return "arrow.right.to.line"
  case .done, .join, .route, .emergencyCall:
    return "checkmark"
  default:
    return "return"
  }
}

/// fcitx5-android `ReturnKey` with an action icon. Google Pinyin always colors it;
/// iOS only does for actions like search or send.
struct EnterView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let returnKeyType: UIReturnKeyType?
  /// Composing: the key commits the preedit, so always show a return icon.
  let cr: Bool

  var body: some View {
    let theme = currentTheme(colorScheme)
    let returnLabel = NSLocalizedString("return", comment: "")
    let symbol = cr ? "return" : returnKeySymbol(returnKeyType)
    let hasReturnLongPress = !cr && symbol != "return"
    let variant: KeyVariant = themeStyle == .ios && symbol == "return" ? .normal : .accent
    Image(systemName: symbol)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: keyIconHeight(height))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: variant, colorScheme: colorScheme,
        action: GestureAction(
          onTap: {
            vm.resetLayerIfNotLocked()
            client.keyPressed("\r", "Enter")
          },
          // WeChat has send type (\n) but supports newline, so provide a way to input \r.
          onLongPress: hasReturnLongPress
            ? { _ in
              vm.resetLayerIfNotLocked()
              client.carriageReturn()
            }
            : nil
        ),
        longPressItems: hasReturnLongPress ? [BubbleItem.text(returnLabel)] : [],
        bubbleFontSize: hasReturnLongPress
          ? adjustFontSize(returnLabel, layoutSwitchFontSize, (width - columnGap) * 0.9) : nil
      )
      .environment(\.colorScheme, theme.isDark ? .dark : .light)
  }
}

enum ShiftState {
  case normal
  case shift
  case capslock
}

/// fcitx5-android `CapsKey`: tap for one letter, long press or double tap to lock.
struct CapsKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  @State private var shiftPressId: Int?

  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  let state: ShiftState

  var body: some View {
    Image(
      systemName: state == .normal ? "shift" : state == .shift ? "shift.fill" : "capslock.fill"
    )
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(height: keyIconHeight(height))
    .keyTile(
      x: x, y: y, width: width, height: height, variant: .alternative, colorScheme: colorScheme,
      action: GestureAction(
        onPress: {
          shiftPressId = vm.beginShiftPress(state: state)
        },
        onDoubleTap: {
          vm.setLayer("shift", lock: true)
        },
        onLongPress: { _ in
          vm.setLayer("shift", lock: true)
        },
        onRelease: {
          if let shiftPressId {
            vm.endShiftPress(shiftPressId)
            self.shiftPressId = nil
          }
        }
      )
    )
  }
}

/// Google Pinyin `softkey_ci`: inputs the pinyin syllable separator ' while composing.
struct SeparatorKeyView: View {
  @Environment(\.colorScheme) var colorScheme
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat

  var body: some View {
    Text("'词")
      .font(.system(size: layoutSwitchFontSize, weight: .medium))
      .accessibilityLabel(NSLocalizedString("Separator", comment: ""))
      .keyTile(
        x: x, y: y, width: width, height: height, variant: .alternative,
        colorScheme: colorScheme,
        action: GestureAction(
          onOrderedKeyPress: {
            return { typeKey("'", "Quote") }
          }))
  }
}

/// fcitx5-android SpaceLongPressBehavior.ShowPicker.
@MainActor
func showInputMethodPicker(_ frame: CGRect) {
  let items = vm.inputMethods.map { inputMethod in
    MenuItem(
      text: inputMethod.displayName,
      action: {
        vm.resetLayerIfNotLocked()
        if vm.englishMode {
          vm.toggleEnglishMode()
        }
        client.setCurrentInputMethod(inputMethod.name)
      })
  }
  if items.count > 1 {
    vm.showContextMenu(frame, items)
  }
}
