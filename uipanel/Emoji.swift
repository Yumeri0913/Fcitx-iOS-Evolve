import SwiftUI
import SwiftUtil

/// Recently used emojis, the first tab of the emoji panel.
enum RecentEmojis {
  private static let key = "RecentEmojis"
  private static let limit = 32

  static func load() -> [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  static func add(_ emoji: String) {
    var list = load().filter { $0 != emoji }
    list.insert(emoji, at: 0)
    UserDefaults.standard.set(Array(list.prefix(limit)), forKey: key)
  }
}

/// Insert an emoji into the editor, also while emoji search takes the keyboard input.
@MainActor
func commitEmoji(_ emoji: String) {
  Haptic.keyPress()
  vm.commitToDocument(emoji)
  RecentEmojis.add(emoji)
}

let emojiColumns = 8

private struct SectionOffsetKey: PreferenceKey {
  static let defaultValue = [Int: CGFloat]()
  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    value.merge(nextValue()) { $1 }
  }
}

/// fcitx5-android's emoji picker: a search button and category tabs on top, the emojis
/// below, and the symbol keyboard's bottom row.
struct EmojiView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight
  let width: CGFloat

  @State private var category = 0
  @State private var recent = RecentEmojis.load()

  var body: some View {
    let theme = currentTheme(colorScheme)
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let rowHeight = (keyboardHeight - keyboardTopPadding) / 4
    let cell = width / CGFloat(emojiColumns)

    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(theme.altKeyTextColor)
              .frame(width: barHeight, height: barHeight)
              .contentShape(Rectangle())
              .onTapGesture { vm.startEmojiSearch() }
              .accessibilityLabel(NSLocalizedString("Search emoji", comment: ""))
            ForEach(0...emojiCategories.count, id: \.self) { i in
              Image(systemName: i == 0 ? "clock" : emojiCategories[i - 1].icon)
                .font(.system(size: 16))
                .foregroundColor(
                  category == i ? theme.accentKeyBackgroundColor : theme.altKeyTextColor
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                  category = i
                  proxy.scrollTo(i, anchor: .top)
                }
            }
          }
          .frame(width: width, height: barHeight)

          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
              // No empty recent section: it would be highlighted at the top.
              ForEach(
                recent.isEmpty ? 1...emojiCategories.count : 0...emojiCategories.count, id: \.self
              ) { i in
                let emojis = i == 0 ? recent : emojiCategories[i - 1].emojis
                LazyVGrid(
                  columns: Array(
                    repeating: GridItem(.fixed(cell), spacing: 0), count: emojiColumns),
                  spacing: 0
                ) {
                  ForEach(emojis, id: \.self) { emoji in
                    Text(emoji)
                      .font(.system(size: 28))
                      .frame(width: cell, height: cell)
                      .contentShape(Rectangle())
                      .onTapGesture { commitEmoji(emoji) }
                  }
                }
                .id(i)
                .background(
                  GeometryReader { geometry in
                    Color.clear.preference(
                      key: SectionOffsetKey.self,
                      value: [i: geometry.frame(in: .named("emoji")).minY])
                  })
              }
            }
          }
          .coordinateSpace(name: "emoji")
          .onPreferenceChange(SectionOffsetKey.self) { offsets in
            // Highlight the section at the top: the last one starting above it.
            if let top = offsets.filter({ $0.value <= 1 }).max(by: { $0.value < $1.value })?.key
              ?? offsets.keys.min()
            {
              category = top
            }
          }
          .scrollIndicators(.hidden)
          .frame(width: width, height: keyboardTopPadding + rowHeight * 3)
        }
      }
      SymbolBottomRow(width: width, height: rowHeight)
    }
    .onAppear {
      recent = RecentEmojis.load()
      category = recent.isEmpty ? 1 : 0
    }
  }
}

/// Gboard style search box in place of the toolbar while searching emojis.
struct EmojiSearchBar: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  var body: some View {
    let theme = currentTheme(colorScheme)
    let text = viewModel.emojiQuery + viewModel.emojiSearchPreedit
    HStack(spacing: 6) {
      ToolButton(systemName: "arrow.backward", iconSize: 18) { vm.endEmojiSearch() }
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass").foregroundColor(theme.altKeyTextColor)
        Text(text.isEmpty ? NSLocalizedString("Search emoji", comment: "") : text)
          .foregroundColor(text.isEmpty ? theme.altKeyTextColor : theme.keyTextColor)
          .lineLimit(1)
        Spacer(minLength: 0)
        if !text.isEmpty {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(theme.altKeyTextColor)
            .onTapGesture { vm.clearEmojiQuery() }
        }
      }
      .font(.system(size: 16))
      .padding(.horizontal, 10)
      .frame(height: barHeight - 8)
      .background(theme.keyBackgroundColor)
      .cornerRadius((barHeight - 8) / 2)
      .padding(.trailing, 8)
    }
    .frame(width: width, height: barHeight)
  }
}

/// A row of search results above the keyboard.
struct EmojiResultsRow: View {
  @Environment(\.colorScheme) var colorScheme
  @ObservedObject private var viewModel = vm
  let width: CGFloat

  var body: some View {
    let theme = currentTheme(colorScheme)
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        if viewModel.emojiResults.isEmpty {
          Text(
            viewModel.emojiQuery.isEmpty
              ? NSLocalizedString("Type a keyword, e.g. 猫 or cat", comment: "")
              : NSLocalizedString("No emoji found", comment: "")
          )
          .font(.system(size: 14))
          .foregroundColor(theme.altKeyTextColor)
          .padding(.horizontal, 12)
        }
        ForEach(viewModel.emojiResults, id: \.self) { emoji in
          Text(emoji)
            .font(.system(size: 28))
            .frame(width: emojiResultsRowHeight, height: emojiResultsRowHeight)
            .contentShape(Rectangle())
            .onTapGesture { commitEmoji(emoji) }
        }
      }
    }
    .scrollIndicators(.hidden)
    .frame(width: width, height: emojiResultsRowHeight)
  }
}

let emojiResultsRowHeight: CGFloat = 48
