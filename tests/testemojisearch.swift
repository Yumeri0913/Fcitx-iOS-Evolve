import Foundation

// Ported from InsightKey's EmojiSearchIndexTest.kt. Arguments: zh.dict en.dict.

private var failures = 0

private func expect(_ condition: Bool, _ message: String) {
  if !condition {
    print("FAILED: \(message)")
    failures += 1
  }
}

@main
struct EmojiSearchTests {
  static func main() {
    let args = CommandLine.arguments
    guard args.count == 3,
      let zh = (try? Data(contentsOf: URL(fileURLWithPath: args[1]))).flatMap(
        EmojiSearchIndex.parse),
      let en = (try? Data(contentsOf: URL(fileURLWithPath: args[2]))).flatMap(
        EmojiSearchIndex.parse)
    else {
      fatalError("cannot load zh.dict and en.dict")
    }
    // loadsCldrData
    expect(zh.emojis.count > 3000 && en.emojis.count > 3000, "CLDR data loaded")
    // chineseExactMatchFirst
    expect(zh.search("猫").first == "🐱", "猫 -> 🐱")
    expect(zh.search("笑哭了").contains("😂"), "笑哭了 -> 😂")
    expect(zh.search("真棒").first == "👍", "真棒 -> 👍")
    // englishPrefixAndCaseInsensitive
    expect(en.search("Cat").contains("🐱"), "Cat")
    expect(!en.search("smil").isEmpty, "smil")
    expect(en.search("thumbs").contains("👍"), "thumbs")
    // empty query
    expect(zh.search("   ").isEmpty, "blank query")
    expect(zh.search("笑", limit: 5).count <= 5, "limit")
    if failures > 0 {
      fatalError("\(failures) emoji search tests failed")
    }
    print("Emoji search tests passed")
  }
}
