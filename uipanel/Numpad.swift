import SwiftUI

/// Google Pinyin 4.x digit keyboard (keyboard_non_prime_digit), reached from the text keyboard
/// and used automatically for numeric fields. Keys commit directly.
struct NumpadView: View {
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject var viewModel = vm

  let width: CGFloat

  var body: some View {
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let layout = KeyboardLayouts.number
    let rowHeight = (keyboardHeight - keyboardTopPadding) / CGFloat(layout.count)

    VStack(spacing: 0) {
      ToolbarView(width: width)
      ZStack(alignment: .topLeading) {
        KeyboardRowsView(
          layout: layout, width: width, height: keyboardHeight, layer: "default",
          lock: false, spaceLabel: viewModel.spaceLabel, returnKeyType: viewModel.returnKeyType,
          hasPreedit: viewModel.hasPreedit)
        // Over the blank keys of the first three rows.
        NumpadSidePanel(width: width * numberSideWidth, height: rowHeight * 3)
          .offset(y: keyboardTopPadding)
      }
      .frame(width: width, height: keyboardHeight)
    }
  }
}

/// Google Pinyin's digit keyboard left panel: + - * / ( ), four at a time, scrolled by
/// dragging; a touch that does not scroll types the symbol under it.
struct NumpadSidePanel: View {
  @Environment(\.colorScheme) var colorScheme
  let width: CGFloat
  let height: CGFloat

  @State private var scroll: CGFloat = 0
  @State private var scrollAtStart: CGFloat = 0
  @State private var scrolling = false
  @State private var touching = false
  @State private var pressed: Int? = nil

  private var itemHeight: CGFloat { height / CGFloat(numberSidePanelVisible) }
  private var maxScroll: CGFloat {
    itemHeight * CGFloat(max(0, numberSidePanel.count - numberSidePanelVisible))
  }

  private func index(at y: CGFloat) -> Int? {
    let i = Int((y + scroll) / itemHeight)
    return i >= 0 && i < numberSidePanel.count ? i : nil
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    VStack(spacing: 0) {
      ForEach(Array(numberSidePanel.enumerated()), id: \.offset) { i, symbol in
        Text(symbol)
          .font(.system(size: min(keyLabelFontSize, itemHeight * 0.7)))
          .foregroundColor(keyForeground(.alternative, theme))
          .frame(width: width - columnGap, height: itemHeight - rowGap)
          .background(
            RoundedRectangle(cornerRadius: keyCornerRadius)
              .fill(
                pressed == i ? theme.keyPressHighlightColor : keyBackground(.alternative, theme))
          )
          .frame(width: width, height: itemHeight)
      }
    }
    .offset(y: -scroll)
    .frame(width: width, height: height, alignment: .top)
    .clipped()
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          if !touching {
            touching = true
            scrolling = false
            scrollAtStart = scroll
            pressed = index(at: value.startLocation.y)
            Haptic.keyPress()
          }
          let dy = value.translation.height
          if !scrolling && abs(dy) > 8 {
            scrolling = true
            pressed = nil
          }
          if scrolling {
            scroll = min(max(scrollAtStart - dy, 0), maxScroll)
          }
        }
        .onEnded { value in
          touching = false
          pressed = nil
          if !scrolling, let i = index(at: value.startLocation.y) {
            vm.resetLayerIfNotLocked()
            client.resetInput()
            client.forwardKey(numberSidePanel[i], "")
          } else if scrolling {
            // settle on whole keys like a list
            scroll = min(max((scroll / itemHeight).rounded() * itemHeight, 0), maxScroll)
          }
          scrolling = false
        })
  }
}
