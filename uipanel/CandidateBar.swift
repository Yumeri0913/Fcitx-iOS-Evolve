import SwiftUI
import UIPanel

let candidateCountInRow = 10
let candidateCountInScreen = 36

private func preeditWithCaret(_ preedit: String, _ caret: Int) -> String {
  if preedit.isEmpty {
    return ""
  }
  var index = 0
  if caret > 0 {
    var utf8 = 0
    for char in preedit {
      index += 1
      utf8 += char.utf8.count
      if utf8 == caret {
        break
      }
    }
  }
  return String(preedit.prefix(index) + "‸" + preedit.suffix(preedit.count - index))
}

/// Candidate bar after fcitx5-android `CandidateUi`: a horizontal candidate list
/// with a 40 dp expand button at the end. Expanded, it becomes a grid with a
/// paging / backspace / return column like `ExpandedCandidateWindow`.
struct CandidateBarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.totalHeight) var totalHeight

  let width: CGFloat
  let auxUp: String
  let preedit: String
  let caret: Int
  let candidates: [String]
  let inputContext: String
  let highlighted: Int
  let rowItemCount: [Int]
  let tabActions: [CandidateAction]
  let batch: Int
  let scrollEnd: Bool
  let hasPrev: Bool
  let hasNext: Bool
  let returnKeyType: UIReturnKeyType?
  let hasPreedit: Bool
  @Binding var expanded: Bool
  @Binding var pendingScroll: Int
  @State private var visibleRows = Set<Int>()
  @State private var scrollMetrics = ScrollMetrics()

  // iOS 18+ reads the real scroll offset; older iOS approximates via visibleRows
  // (the first/last row has fully left the viewport).
  private var scrollDisabledState: (up: Bool, down: Bool) {
    let isBulk = pendingScroll >= 0
    if #available(iOS 18.0, *) {
      return (
        isBulk ? scrollMetrics.offset <= 1 : !hasPrev,
        isBulk
          ? scrollEnd
            && scrollMetrics.offset
              >= scrollMetrics.contentHeight - scrollMetrics.containerHeight - 1
          : !hasNext
      )
    } else {
      return (
        isBulk ? (visibleRows.min() ?? 0) == 0 : !hasPrev,
        isBulk
          ? scrollEnd && (visibleRows.max() ?? -1) >= rowItemCount.count - 1 : !hasNext
      )
    }
  }

  private func loadMoreCandidates(_ start: Int, _ count: Int) {
    if pendingScroll < start {
      pendingScroll = start
      scroll(inputContext, Int32(start), Int32(count))
    }
  }

  var body: some View {
    let theme = currentTheme(colorScheme)
    let barHeight = getBarHeight(totalHeight)
    let keyboardHeight = getKeyboardHeight(totalHeight)
    let hasAuxPreedit = !auxUp.isEmpty || !preedit.isEmpty
    // A keyboard extension cannot float the preedit above its frame like Android,
    // so the preedit shares the bar with the candidates.
    let stripHeight: CGFloat = hasAuxPreedit ? preeditStripHeight : 0
    let candidateRowHeight = barHeight - stripHeight
    let fontSize = hasAuxPreedit ? candidateFontSizeWithPreedit : candidateFontSize
    let marginTop = max((5 * candidateRowHeight - keyboardHeight) / 11, 0)
    let paddingBottom = max((keyboardHeight - 5 * candidateRowHeight) / 6, 0)
    let expandedListHeight = candidateRowHeight + keyboardHeight - marginTop
    let expandedCandidateHeight = expandedListHeight / 6 - paddingBottom
    let expandedListWidth = width * 4 / 5
    let tabActionColumnWidth = expandedListWidth / 6
    let candidateListWidth =
      tabActions.isEmpty ? expandedListWidth : expandedListWidth - tabActionColumnWidth

    ScrollViewReader { proxy in
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          if hasAuxPreedit {
            // PreeditUi: key text color, left aligned.
            Text(auxUp + preeditWithCaret(preedit, caret))
              .font(.system(size: preeditFontSize))
              .foregroundColor(theme.keyTextColor)
              .lineLimit(1)
              .frame(height: stripHeight)
              .padding([.leading], 8)
          }

          if expanded {
            if marginTop > 0 {
              Spacer().frame(height: marginTop)
            }
            HStack(spacing: 0) {
              if !tabActions.isEmpty {
                CandidateTabActionColumnView(
                  inputContext: inputContext, actions: tabActions, width: tabActionColumnWidth,
                  actionHeight: expandedCandidateHeight,
                  paddingBottom: paddingBottom,
                  height: expandedListHeight)
              }
              ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                  ForEach(rowItemCount.indices, id: \.self) { row in
                    HStack(spacing: 0) {
                      ForEach(0..<rowItemCount[row], id: \.self) { col in
                        let index = rowItemCount.prefix(row).reduce(0, +) + col
                        if index < candidates.count {
                          CandidateView(
                            text: candidates[index], inputContext: inputContext, index: index,
                            highlighted: highlighted
                          )
                          .frame(minWidth: width / 8).frame(
                            height: expandedCandidateHeight
                          )
                        }
                      }
                    }.onAppear {
                      visibleRows.insert(row)
                      if pendingScroll >= 0 && !scrollEnd && row == rowItemCount.count - 5 {
                        loadMoreCandidates(candidates.count, candidateCountInScreen)
                      }
                    }.onDisappear {
                      visibleRows.remove(row)
                    }
                    if paddingBottom > 0 {
                      Spacer().frame(height: paddingBottom)
                    }
                  }
                }
              }.frame(width: candidateListWidth, height: expandedListHeight)
                .scrollIndicators(.hidden)
                .onChange(of: batch) { _ in
                  proxy.scrollTo(0, anchor: .leading)
                }
                .onScrollMetricsChange { scrollMetrics = $0 }
            }
          } else {
            ScrollView(.horizontal) {
              // Use LazyHStack so that onAppear is triggered only when candidate is scrolled into view.
              LazyHStack(spacing: candidateGap) {
                ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                  CandidateView(
                    text: candidate, inputContext: inputContext, index: index,
                    highlighted: highlighted, fontSize: fontSize
                  ).onAppear {
                    if pendingScroll >= 0 && !scrollEnd
                      && index == candidates.count - candidateCountInRow
                    {
                      loadMoreCandidates(candidates.count, candidateCountInRow)
                    }
                  }
                }
                Spacer()
              }.frame(
                height: candidateRowHeight
              )
              // Force re-render, otherwise scrolling to the first candidate may fail due to the first isn't rendered.
              .id(batch)
            }.scrollIndicators(.hidden)
              .padding([.leading], 4)
              .onChange(of: [batch, highlighted]) { newValues in
                // Watch batch instead of candidates because we don't want to reset on loading more.
                let newHighlighted = newValues[1]
                // Test in mozc by typing mizu and space through all candidates.
                proxy.scrollTo(
                  newHighlighted,
                  anchor: newHighlighted == candidates.count - 1 ? .leading : .trailing)
              }
          }
        }

        if expanded {
          VStack(alignment: .trailing, spacing: 0) {  // trailing for collapse button
            ToolButton(systemName: "chevron.up") {
              expanded.toggle()
            }
            .frame(height: barHeight)

            let keyHeight = keyboardHeight / 4
            let keyWidth = width / 5

            Image(systemName: "arrow.up")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: keyIconHeight(keyHeight))
              .keyTile(
                x: 0, y: 0, width: keyWidth, height: keyHeight, variant: .alternative,
                colorScheme: colorScheme,
                action: GestureAction(
                  onTap: {
                    if pendingScroll >= 0 {
                      withAnimation {
                        proxy.scrollTo(((visibleRows.min() ?? 0) - 1) / 5 * 5, anchor: .top)
                      }
                    } else {
                      page(inputContext, false)
                    }
                  }
                ),
                disable: scrollDisabledState.up
              )

            Image(systemName: "arrow.down")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: keyIconHeight(keyHeight))
              .keyTile(
                x: 0, y: 0, width: keyWidth, height: keyHeight, variant: .alternative,
                colorScheme: colorScheme,
                action: GestureAction(
                  onTap: {
                    if pendingScroll >= 0 {
                      withAnimation {
                        proxy.scrollTo(((visibleRows.min() ?? 0) + 1) / 5 * 5 + 5, anchor: .top)
                      }
                    } else {
                      page(inputContext, true)
                    }
                  }
                ),
                disable: scrollDisabledState.down
              )

            BackspaceView(x: 0, y: 0, width: keyWidth, height: keyHeight)

            EnterView(
              x: 0, y: 0, width: keyWidth, height: keyHeight,
              returnKeyType: returnKeyType, cr: hasPreedit)
          }
        } else {
          if candidates.isEmpty {
            DismissKeyboardButton()
          } else {
            ToolButton(systemName: "chevron.down") {
              expanded.toggle()
            }
          }
        }
      }
    }
  }
}
