import SwiftUI

/// fcitx5-android `NumberKeyboard` ("?123"), reached from the text keyboard
/// and used automatically for numeric fields. Keys commit directly.
struct NumpadView: View {
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject var viewModel = vm

  let width: CGFloat

  var body: some View {
    let keyboardHeight = getKeyboardHeight(totalHeight)

    VStack(spacing: 0) {
      ToolbarView(width: width)
      KeyboardRowsView(
        layout: KeyboardLayouts.number, width: width, height: keyboardHeight, layer: "default",
        lock: false, spaceLabel: viewModel.spaceLabel, returnKeyType: viewModel.returnKeyType,
        hasPreedit: viewModel.hasPreedit)
    }
  }
}
