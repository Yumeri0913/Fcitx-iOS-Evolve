import SwiftUI
import SwiftUtil
import UIPanel

struct CandidateAction: Codable, Identifiable {
  let id: Int32
  let text: String
  let checked: Bool
  let checkable: Bool
  let separator: Bool
}

/// fcitx5-android `CandidateItemUi`: 20 sp text in the candidate color with a
/// press highlight; the fcitx cursor uses the same highlight.
struct CandidateView: View {
  @Environment(\.colorScheme) var colorScheme
  let text: String
  let inputContext: String
  let index: Int
  let highlighted: Int
  var fontSize: CGFloat = candidateFontSize
  @State private var isPressed = false

  var body: some View {
    let theme = currentTheme(colorScheme)
    Text(text).font(.system(size: fontSize))
      .foregroundColor(theme.candidateTextColor)
      .lineLimit(1)
      .padding([.leading, .trailing], candidateHorizontalPadding)
      .frame(maxHeight: .infinity)
      .background(index == highlighted || isPressed ? theme.keyPressHighlightColor : .clear)
      .cornerRadius(keyCornerRadius)
      .onTapGesture {
        Haptic.keyPress()
        selectCandidate(inputContext, Int32(index))
      }.onContextMenu(
        onPressingChanged: { pressing in
          isPressed = pressing
        },
        {
          let actions = deserialize(
            [CandidateAction].self, String(getCandidateActions(inputContext, Int32(index))))
          return actions.map { action in
            MenuItem(
              text: action.text,
              action: { activateCandidateAction(inputContext, Int32(index), action.id) })
          }
        })
  }
}
