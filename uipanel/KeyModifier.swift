import SwiftUI
import SwiftUtil

struct GestureAction {
  var onOrderedKeyPress: (() -> (() -> Void))? = nil
  /// Like onOrderedKeyPress, given the touch point in keyboard coordinates.
  var onOrderedKeyPressAt: ((CGPoint) -> (() -> Void))? = nil
  /// Called on release after the finger moved off its start, with start and end in
  /// keyboard coordinates, before onSwipe. Returns true if it handled the touch.
  var onSlideOff: ((CGPoint, CGPoint) -> Bool)? = nil
  var onPress: (() -> Void)? = nil
  var onTap: (() -> Void)? = nil
  var onDoubleTap: (() -> Void)? = nil
  var onLongPress: ((Int) -> Void)? = nil
  var onSwipe: ((SwipeDirection) -> Void)? = nil
  var onSlide: ((Int) -> Void)? = nil
  var onRelease: (() -> Void)? = nil
}

enum SwipeDirection {
  case up, down, left, right
}

private func getSwipeDirection(_ dx: CGFloat, _ dy: CGFloat) -> SwipeDirection {
  if abs(dx) > abs(dy) {
    return dx > 0 ? .right : .left
  }
  return dy > 0 ? .down : .up
}

private func getNStep(_ start: CGFloat, _ end: CGFloat, _ step: CGFloat) -> Int {
  return (start < end ? 1 : -1) * Int(floor(abs(end - start) / step))
}

@MainActor
private func clearBubble() {
  vm.setBubble(0, 0, 0, 0, .clear, .light, .clear, nil, [], 0, 0, nil)
}

struct KeyModifier: ViewModifier {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.keyBorder) var keyBorder

  // Google Pinyin 4.5.2: swipe symbol threshold 16 dp (~2.5 mm), space scrub one
  // character per 8 pt (~2.8 mm) and only 200 ms after touch down.
  let threshold: CGFloat = 16
  let stepSize: CGFloat = 18
  let slideDelay: TimeInterval = 0.2

  @State private var touchId = 0
  @State private var lastTouchTime: Date?
  @State private var isPressed = false
  @State private var isTouchAccepted = false
  @State private var isTouchStarted = false
  @State private var startLocation: CGPoint?
  @State private var touchStartTime = Date.distantPast
  @State private var lastLocation: CGFloat?
  @State private var didTriggerLongPress = false
  @State private var didMoveFarEnough = false
  @State private var slideActivated = false
  @State private var bubbleHighlight = 0
  @State private var orderedKeyPressId: Int?

  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
  let hMargin: CGFloat
  let vMargin: CGFloat
  let radius: CGFloat
  let background: Color
  let bubbleBackground: Color?
  let bubbleFontSize: CGFloat?
  let foreground: Color
  let highlight: Color
  let shadow: Color
  let action: GestureAction
  let disable: Bool
  let pressedView: (any View)?
  let bubbleLabel: String?
  let swipeLabel: String?
  /// Shown when swiping up instead of swipeLabel.
  let swipeUpLabel: String?
  let longPressItems: [BubbleItem]
  let longPressIndex: Int
  let longPressDelay: TimeInterval
  /// Touch area beyond the key's cell, e.g. a and l reach the screen edges.
  let hitLeading: CGFloat
  let hitTrailing: CGFloat

  /// Local touch location to keyboard coordinates.
  private func keyboardPoint(_ location: CGPoint) -> CGPoint {
    CGPoint(x: x - hitLeading + location.x, y: y + location.y)
  }
  var bubbleX: CGFloat { x + width / 2 }
  var bubbleY: CGFloat { y + height / 2 }
  var bubbleWidth: CGFloat { width - hMargin }
  var bubbleHeight: CGFloat { height - vMargin }

  private var popupBackground: Color {
    bubbleBackground ?? currentTheme(colorScheme).popupBackgroundColor
  }

  private var accentBackground: Color {
    currentTheme(colorScheme).accentKeyBackgroundColor
  }

  private var popupShadow: Color {
    currentTheme(colorScheme).keyShadowColor
  }

  private func cancelOrderedKeyPress() {
    if let id = orderedKeyPressId {
      vm.removeOrderedKeyPress(id)
      orderedKeyPressId = nil
    }
  }

  private func processedByAnotherKeyPress() -> Bool {
    if let id = orderedKeyPressId, vm.orderedKeyPressWasSent(id) {
      return true
    }
    return false
  }

  private func isDoubleTap(_ touchTime: Date) -> Bool {
    if action.onDoubleTap != nil, let t = lastTouchTime,
      touchTime.timeIntervalSince(t) < 0.3
    {
      return true
    }
    return false
  }

  private func showLongPressBubble() {
    vm.setBubble(
      bubbleX, bubbleY, bubbleWidth, bubbleHeight,
      popupBackground, colorScheme, popupShadow, nil, longPressItems, longPressIndex,
      bubbleHighlight, bubbleFontSize)
  }

  private func onTimer(_ currentTouchId: Int) {
    if touchId != currentTouchId {
      // Called from a previous touch.
      return
    }
    if processedByAnotherKeyPress() {
      return
    }
    if isPressed && !didTriggerLongPress && !didMoveFarEnough {
      cancelOrderedKeyPress()
      didTriggerLongPress = true
      if !longPressItems.isEmpty {
        bubbleHighlight = max(0, min(longPressIndex, longPressItems.count - 1))
        showLongPressBubble()
      } else {
        clearBubble()
        action.onLongPress?(0)
      }
    }
  }

  private func onTouchStart(_ location: CGPoint) {
    if isTouchStarted {
      return
    }
    isTouchStarted = true
    if disable {
      isTouchAccepted = false
      return
    }
    isTouchAccepted = true
    let touchTime = Date()
    touchId = (touchId + 1) & 0xFFFF
    let currentTouchId = touchId
    isPressed = true
    Haptic.keyPress()
    startLocation = location
    touchStartTime = touchTime
    lastLocation = location.x

    vm.setBubble(
      bubbleX, bubbleY, bubbleWidth, bubbleHeight,
      popupBackground, colorScheme, popupShadow,
      bubbleLabel, [], 0, 0, bubbleFontSize)

    vm.flushOrderedKeyPresses()
    if isDoubleTap(touchTime) {
      lastTouchTime = nil
      action.onDoubleTap?()
    } else {  // Single tap
      lastTouchTime = touchTime
      if let onOrderedKeyPressAt = action.onOrderedKeyPressAt {
        orderedKeyPressId = vm.beginOrderedKeyPress(onOrderedKeyPressAt(keyboardPoint(location)))
      } else if let onOrderedKeyPress = action.onOrderedKeyPress {  // Normal keys
        orderedKeyPressId = vm.beginOrderedKeyPress(onOrderedKeyPress())
      } else {  // Shift
        action.onPress?()
      }
    }

    // Schedule long press that can be interrupted by move.
    DispatchQueue.main.asyncAfter(deadline: .now() + longPressDelay) {
      onTimer(currentTouchId)
    }
  }

  /// Map a finger offset from the touch start to a popup cell, as sliding over
  /// fcitx5-android's popup keyboard.
  private func popupHighlight(_ dx: CGFloat, _ dy: CGFloat) -> Int {
    let count = longPressItems.count
    let columns = popupColumns(count)
    let rows = popupRows(count)
    let anchor = popupAnchorColumn(
      keyCenterX: bubbleX, cellWidth: bubbleWidth, columns: columns,
      preferredColumn: longPressIndex, keyboardWidth: vm.totalWidth)
    let column = max(0, min(anchor + Int((dx / bubbleWidth).rounded()), columns - 1))
    let row = max(0, min(Int(((-dy) / bubbleHeight).rounded()), rows - 1))
    return min(row * columns + column, count - 1)
  }

  private func onTouchMove(_ location: CGPoint) {
    if disable {
      return
    }
    if processedByAnotherKeyPress() {
      return
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if !didTriggerLongPress {
      if !didMoveFarEnough && (abs(dx) > threshold || abs(dy) > threshold) {
        didMoveFarEnough = true
        cancelOrderedKeyPress()
      }
      if didMoveFarEnough {
        let direction = getSwipeDirection(dx, dy)
        if direction == .up || direction == .down,
          let label = direction == .up ? swipeUpLabel ?? swipeLabel : swipeLabel
        {
          vm.setBubble(
            bubbleX, bubbleY, bubbleWidth, bubbleHeight, popupBackground,
            colorScheme, popupShadow, label, [], 0, 0, bubbleFontSize)
        } else {
          clearBubble()
        }
      }
    }
    // Process slide and long press + move.
    if let onSlide = action.onSlide {
      if !slideActivated {
        if abs(dx) >= threshold, Date().timeIntervalSince(touchStartTime) >= slideDelay,
          let start = startLocation
        {
          slideActivated = true
          lastLocation = start.x + (dx > 0 ? threshold : -threshold)
        }
      }
      if slideActivated {
        if let start = startLocation, let last = lastLocation {
          let totalPast = getNStep(start.x, last, stepSize)
          let totalNow = getNStep(start.x, location.x, stepSize)
          let delta = totalNow - totalPast
          if delta != 0 {
            onSlide(delta)
          }
          lastLocation = location.x
        }
      }
    } else if didTriggerLongPress && longPressItems.count > 1 {
      let newHighlight = popupHighlight(dx, dy)
      if newHighlight != bubbleHighlight {
        bubbleHighlight = newHighlight
        showLongPressBubble()
      }
    }
  }

  private func onTouchEnd(_ location: CGPoint) {
    clearBubble()
    defer {
      cancelOrderedKeyPress()
      if isTouchAccepted {
        action.onRelease?()
      }
      isTouchAccepted = false
      isTouchStarted = false
      isPressed = false
      startLocation = nil
      lastLocation = nil
      didTriggerLongPress = false
      didMoveFarEnough = false
      slideActivated = false
      bubbleHighlight = 0
    }

    if !isTouchAccepted {
      return
    }

    if processedByAnotherKeyPress() {
      return
    }

    let dx = location.x - (startLocation?.x ?? 0)
    let dy = location.y - (startLocation?.y ?? 0)

    if slideActivated {
      if let onSlide = action.onSlide {
        onSlide(0)
        return
      }
    }

    if didTriggerLongPress && !longPressItems.isEmpty && bubbleHighlight >= 0
      && bubbleHighlight < longPressItems.count
    {
      action.onLongPress?(bubbleHighlight)
      return
    }

    if didMoveFarEnough {
      if !didTriggerLongPress, let onSlideOff = action.onSlideOff, let start = startLocation,
        onSlideOff(keyboardPoint(start), keyboardPoint(location))
      {
        return
      }
      if !didTriggerLongPress {
        action.onSwipe?(getSwipeDirection(dx, dy))
      }
    } else {
      if !didTriggerLongPress {
        if let id = orderedKeyPressId {
          vm.releaseOrderedKeyPress(id)
          return
        }
        action.onTap?()
      }
    }
  }

  func body(content: Content) -> some View {
    let tileWidth = width - hMargin
    let tileHeight = height - vMargin
    VStack {
      if isPressed, let pressedView = pressedView {
        AnyView(pressedView)
      } else {
        content
      }
    }.frame(width: tileWidth, height: tileHeight)
      .foregroundColor(foreground)
      // Without key border only the accent (return) key keeps its fill.
      .background(keyBorder || background == accentBackground ? background : Color.clear)
      // fcitx5-android draws the press highlight over the key background.
      .overlay(isPressed ? highlight : Color.clear)
      .cornerRadius(radius)
      .condition(keyBorder) {
        $0.overlay(
          ShadowView(width: tileWidth, height: 1, radius: radius, color: shadow)
            .offset(y: (tileHeight - radius + 1) / 2)
        )
      }
      .opacity(disable ? 0.38 : 1)
      .frame(width: width, height: height)
      .padding(.leading, hitLeading)
      .padding(.trailing, hitTrailing)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !isPressed {
              onTouchStart(value.startLocation)
            } else {
              onTouchMove(value.location)
            }
          }
          .onEnded { value in
            onTouchEnd(value.location)
          }
      ).position(x: x - hitLeading + (hitLeading + width + hitTrailing) / 2, y: y + height / 2)
  }
}

extension View {
  @ViewBuilder
  func condition<Content: View>(
    _ isActive: Bool,
    transform: (Self) -> Content
  ) -> some View {
    if isActive {
      transform(self)
    } else {
      self
    }
  }

  @MainActor
  func keyProperties(
    x: CGFloat = 0, y: CGFloat = 0,
    width: CGFloat, height: CGFloat, hMargin: CGFloat = columnGap, vMargin: CGFloat? = nil,
    radius: CGFloat = keyCornerRadius, background: Color,
    foreground: Color, highlight: Color, shadow: Color, action: GestureAction,
    pressedView: (any View)? = nil, bubbleLabel: String? = nil,
    swipeLabel: String? = nil, swipeUpLabel: String? = nil,
    longPressItems: [BubbleItem]? = nil, longPressIndex: Int? = nil,
    bubbleBackground: Color? = nil, bubbleFontSize: CGFloat? = nil, disable: Bool = false,
    longPressDelay: TimeInterval = 0.3, hitLeading: CGFloat = 0, hitTrailing: CGFloat = 0
  ) -> some View {
    self.modifier(
      KeyModifier(
        x: x, y: y, width: width, height: height, hMargin: hMargin, vMargin: vMargin ?? rowGap,
        radius: radius,
        background: background, bubbleBackground: bubbleBackground,
        bubbleFontSize: bubbleFontSize,
        foreground: foreground, highlight: highlight,
        shadow: shadow, action: action, disable: disable, pressedView: pressedView,
        bubbleLabel: bubbleLabel, swipeLabel: swipeLabel, swipeUpLabel: swipeUpLabel,
        longPressItems: longPressItems ?? [],
        longPressIndex: longPressIndex ?? 0,
        longPressDelay: longPressDelay, hitLeading: hitLeading, hitTrailing: hitTrailing
      )
    )
  }
}

@MainActor
func executeActions(_ actions: [[String: String]]) {
  for action in actions {
    if let type = action["type"] {
      switch type {
      case "key":
        let key = action["key"] ?? ""
        let code = action["code"] ?? ""
        client.keyPressed(key, code)
      default:
        FCITX_ERROR("Unknown action type: \(type)")
      }
    }
  }
}
