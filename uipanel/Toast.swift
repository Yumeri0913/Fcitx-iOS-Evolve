import SwiftUI

struct ToastView: View {
  @Environment(\.colorScheme) private var colorScheme

  let message: String
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text(message)
        .foregroundColor(getNormalForeground(colorScheme))
        .lineLimit(2)
      Spacer(minLength: 8)
      Button(action: action) {
        Text(actionTitle)
          .fontWeight(.semibold)
          .foregroundColor(getAccentBackground(colorScheme))
          .padding(.horizontal, 8)
          .frame(minHeight: 44)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .frame(minHeight: 48)
    .background(getFunctionBackground(colorScheme).blend(with: getBackground(colorScheme)))
    .cornerRadius(8)
    .shadow(radius: 4)
  }
}

/// A message covering the toolbar, dismissed by tap or after a while.
struct NoticeView: View {
  @Environment(\.colorScheme) private var colorScheme

  let message: String

  var body: some View {
    let theme = currentTheme(colorScheme)
    Text(message)
      .font(.system(size: 15))
      .foregroundColor(theme.keyTextColor)
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(theme.keyBackgroundColor)
      .cornerRadius(8)
      .shadow(radius: 2)
      .padding(.vertical, 4)
  }
}
