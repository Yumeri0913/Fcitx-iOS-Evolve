import SwiftUI

/// Quick theme switcher opened from the toolbar palette button. Writes the uipanel
/// addon config, which saves it and applies it to the keyboard right away.
struct ThemePanelView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  private static let uri = "fcitx://config/addon/uipanel"

  /// Enum values are the option's English names, as fcitx marshals them.
  private func save(_ key: String, _ value: String) {
    let json = (try? JSONSerialization.data(withJSONObject: [key: value]))
      .flatMap { String(data: $0, encoding: .utf8) }
    if let json {
      client.setAddonConfig(Self.uri, json)
    }
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    VStack(spacing: 0) {
      ReturnBarView(width: width, title: NSLocalizedString("Theme", comment: ""))
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ThemeOptionRow(
            title: "Theme style",
            options: [("iOS", "iOS"), ("Google Pinyin", "Google Pinyin")],
            selected: themeStyle == .ios ? "iOS" : "Google Pinyin"
          ) { save("ThemeStyle", $0) }
          ThemeOptionRow(
            title: "Appearance",
            options: [("Follow system", "Follow system"), ("Light", "Light"), ("Dark", "Dark")],
            selected: ["Follow system", "Light", "Dark"][viewModel.themeMode.rawValue]
          ) { save("Theme", $0) }
          ThemeOptionRow(
            title: "Key border",
            options: [
              ("Follow theme style", "Follow theme style"), ("On", "On"), ("Off", "Off"),
            ],
            selected: ["Follow theme style", "On", "Off"][viewModel.keyBorderMode.rawValue]
          ) { save("KeyBorder", $0) }
          ThemeOptionRow(
            title: "Key corner radius",
            options: [
              ("Follow theme style", "-1"), ("0", "0"), ("4", "4"), ("8", "8"), ("12", "12"),
            ],
            selected: String(keyRadiusSetting)
          ) { save("KeyRadius", $0) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
      }
    }
    .frame(width: width, height: totalHeight)
    .foregroundColor(theme.keyTextColor)
  }
}

private struct ThemeOptionRow: View {
  @Environment(\.colorScheme) var colorScheme
  let title: String
  /// (label to localize, config value)
  let options: [(String, String)]
  let selected: String
  let onSelect: (String) -> Void

  var body: some View {
    let theme = currentTheme(colorScheme)
    VStack(alignment: .leading, spacing: 6) {
      Text(NSLocalizedString(title, comment: ""))
        .font(.system(size: 13))
        .foregroundColor(theme.altKeyTextColor.opacity(0.7))
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(options, id: \.1) { label, value in
            let isSelected = value == selected
            Text(NSLocalizedString(label, comment: ""))
              .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
              .foregroundColor(isSelected ? theme.accentKeyTextColor : theme.keyTextColor)
              .padding(.horizontal, 14)
              .frame(height: 34)
              .background(isSelected ? theme.accentKeyBackgroundColor : theme.keyBackgroundColor)
              .cornerRadius(keyCornerRadius)
              .contentShape(Rectangle())
              .onTapGesture {
                Haptic.keyPress()
                onSelect(value)
              }
          }
        }
      }
    }
  }
}
