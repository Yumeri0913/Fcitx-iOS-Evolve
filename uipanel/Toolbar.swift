import SwiftUI

// The idle bar of fcitx5-android (`IdleUi` / `ButtonsBarUi`): undo, redo, text
// editing, clipboard and status area spread over the bar, with a hide-keyboard
// button at the end. The InsightKey fork always shows the toolbar, so there is
// no expand/collapse button.

struct ToolButtonStyle: ButtonStyle {
  let highlight: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(Circle().fill(configuration.isPressed ? highlight : Color.clear))
  }
}

/// fcitx5-android `ToolButton`: 40 dp, icon tinted with the alt key text color.
struct ToolButton: View {
  @Environment(\.colorScheme) var colorScheme

  let systemName: String
  var size: CGFloat = toolButtonSize
  var iconSize: CGFloat = toolButtonIconSize
  var enabled = true
  let action: () -> Void

  var body: some View {
    let theme = currentTheme(colorScheme)
    Button {
      Haptic.keyPress()
      action()
    } label: {
      Image(systemName: systemName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: iconSize, height: iconSize)
        .foregroundColor(enabled ? theme.altKeyTextColor : getDisabledForeground(colorScheme))
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }
    .buttonStyle(ToolButtonStyle(highlight: theme.keyPressHighlightColor))
    .disabled(!enabled)
  }
}

struct DismissKeyboardButton: View {
  var body: some View {
    ToolButton(systemName: "arrowtriangle.down.fill", iconSize: 12) {
      client.dismissKeyboard()
    }
  }
}

/// Google Pinyin style 中/英 switch at the start of the toolbar.
struct LanguageToggleButton: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject var viewModel = vm

  var body: some View {
    let theme = currentTheme(colorScheme)
    Button {
      Haptic.keyPress()
      vm.toggleEnglishMode()
    } label: {
      Text(viewModel.languageLabel)
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(theme.altKeyTextColor)
        .frame(width: toolButtonSize, height: toolButtonSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(ToolButtonStyle(highlight: theme.keyPressHighlightColor))
    .accessibilityLabel(NSLocalizedString("Toggle Chinese/English", comment: ""))
  }
}

struct ToolbarButtons: View {
  @ObservedObject var viewModel = vm

  var body: some View {
    HStack(spacing: 0) {
      LanguageToggleButton()
      Spacer(minLength: 0)
      ToolButton(systemName: "arrow.uturn.backward", enabled: viewModel.canUndo) {
        client.undo()
      }
      Spacer(minLength: 0)
      ToolButton(systemName: "arrow.uturn.forward", enabled: viewModel.canRedo) {
        client.redo()
      }
      Spacer(minLength: 0)
      ToolButton(systemName: "character.cursor.ibeam") {
        vm.setDisplayMode(.edit)
      }
      Spacer(minLength: 0)
      ToolButton(systemName: "doc.on.clipboard") {
        vm.setDisplayMode(.clipboard)
      }
      Spacer(minLength: 0)
      ToolButton(systemName: "ellipsis") {
        vm.setDisplayMode(.statusArea)
      }
      Spacer(minLength: 0)
    }
  }
}

/// fcitx5-android `ClipboardSuggestionUi` with the fork's close button.
struct ClipboardSuggestionBar: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject var viewModel = vm

  let text: String

  var body: some View {
    let theme = currentTheme(colorScheme)
    HStack(spacing: 4) {
      Spacer(minLength: 0)
      Button {
        viewModel.pasteClipboardSuggestion()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "doc.on.clipboard")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
          Text(text)
            .font(.system(size: 14))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 160)
        }
        .foregroundColor(theme.altKeyTextColor)
        .padding(.horizontal, 8)
        .frame(height: barHeight - 8)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(viewModel.showMenu ? Color.clear : Color.clear))
      }
      .buttonStyle(ClipboardSuggestionButtonStyle(highlight: theme.keyPressHighlightColor))
      .accessibilityIdentifier("ClipboardSuggestion")
      .disabled(viewModel.showMenu)
      ToolButton(systemName: "xmark", size: 28, iconSize: 14) {
        viewModel.dismissClipboardSuggestion()
      }
      .accessibilityIdentifier("ShowToolbar")
      Spacer(minLength: 0)
    }
  }
}

struct ClipboardSuggestionButtonStyle: ButtonStyle {
  let highlight: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        RoundedRectangle(cornerRadius: 4).fill(configuration.isPressed ? highlight : Color.clear))
  }
}

struct ToolbarView: View {
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  var body: some View {
    HStack(spacing: 0) {
      if let text = viewModel.clipboardSuggestionText {
        ClipboardSuggestionBar(text: text)
          .frame(width: width - toolButtonSize, height: barHeight)
      } else {
        ToolbarButtons()
          .frame(width: width - toolButtonSize, height: barHeight)
      }
      DismissKeyboardButton()
    }
    .frame(width: width, height: barHeight)
    .onAppear { viewModel.refreshClipboardSuggestion() }
  }
}
