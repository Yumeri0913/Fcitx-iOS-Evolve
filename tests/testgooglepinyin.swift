import Foundation

// Ported from InsightKey's GooglePinyinUserDictTest.kt so both platforms parse and
// write Google Pinyin user dictionaries the same way.

private typealias Entry = GooglePinyinUserDict.Entry

private var failures = 0

private func expect(_ condition: Bool, _ message: String) {
  if !condition {
    print("FAILED: \(message)")
    failures += 1
  }
}

private let bomLE = Data([0xFF, 0xFE])
private let gb18030 = String.Encoding(
  rawValue: CFStringConvertEncodingToNSStringEncoding(
    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))

/// What Google Pinyin 4.5 writes on export.
private func googleExport(_ lines: String...) -> Data {
  bomLE
    + (GooglePinyinUserDict.header + "\n" + lines.map { $0 + "\n" }.joined())
    .data(using: .utf16LittleEndian)!
}

private func testParsesGoogleExport() {
  let data = googleExport(
    "你好\t5\tni hao",
    "hello\t3\t\\0 hello",
    "长城\t2\tchang cheng\ttx=1",
    "绿色\t1\tlv se")
  expect(GooglePinyinUserDict.looksLikeGooglePinyin(data), "export looks like Google Pinyin")
  let result = GooglePinyinUserDict.parse(data)
  expect(
    result.entries == [
      Entry(word: "你好", syllables: ["ni", "hao"], count: 5),
      Entry(word: "长城", syllables: ["chang", "cheng"], count: 2),
      Entry(word: "绿色", syllables: ["lv", "se"], count: 1),
    ], "export entries: \(result.entries)")
  // The English entry is not a pinyin word.
  expect(result.skipped == 1, "export skipped: \(result.skipped)")
}

private func testFieldOrderAndSeparatorsAreLenient() {
  let text = """
    ; comment
    ni'hao 你好 3
    7\tzhong|guo\t中国
    略微\tlue'wei
    女\t1\tnü
    """
  let result = GooglePinyinUserDict.parse(text)
  expect(
    result.entries == [
      Entry(word: "你好", syllables: ["ni", "hao"], count: 3),
      Entry(word: "中国", syllables: ["zhong", "guo"], count: 7),
      Entry(word: "略微", syllables: ["lve", "wei"], count: 1),
      Entry(word: "女", syllables: ["nv"], count: 1),
    ], "lenient entries: \(result.entries)")
  expect(result.skipped == 0, "lenient skipped: \(result.skipped)")
}

private func testSkipsInvalidEntries() {
  let result = GooglePinyinUserDict.parse(
    [
      "你好\t1\tni",  // syllable count mismatch
      "卡拉OK\t1\tka la o k",  // non-Han characters
      "测试\t1\tce shix",  // invalid syllable
      "\t1\tni hao",  // no word
      "你好\t1",  // no pinyin
      "你好\t2\tni hao",
      "你好\t9\tni'hao",  // duplicate keeps max count
    ].joined(separator: "\n"))
  expect(
    result.entries == [Entry(word: "你好", syllables: ["ni", "hao"], count: 9)],
    "invalid entries: \(result.entries)")
  expect(result.skipped == 5, "invalid skipped: \(result.skipped)")
}

private func testDecodesByBomOrFallsBackToGbk() {
  let text = "你好\t1\tni hao\n"
  expect(GooglePinyinUserDict.decode(text.data(using: gb18030)!) == text, "GBK")
  let utf8 = Data(text.utf8)
  expect(GooglePinyinUserDict.decode(utf8) == text, "UTF-8")
  let be = Data([0xFE, 0xFF]) + text.data(using: .utf16BigEndian)!
  expect(GooglePinyinUserDict.decode(be) == text, "UTF-16BE")
  let utf8Bom = Data([0xEF, 0xBB, 0xBF]) + utf8
  expect(GooglePinyinUserDict.decode(utf8Bom) == text, "UTF-8 BOM")
}

private func testDoesNotMistakeLibimeTextForGoogle() {
  let libime = Data("你好 ni'hao 0\n中国 zhong'guo 0\n".utf8)
  expect(!GooglePinyinUserDict.looksLikeGooglePinyin(libime), "libime text is not Google")
  let gbkTsv = "你好\t3\tni hao\n中国\t1\tzhong guo\n".data(using: gb18030)!
  expect(GooglePinyinUserDict.looksLikeGooglePinyin(gbkTsv), "GBK TSV is Google")
}

private func testWritesGoogleFormatThatRoundTrips() {
  let entries = [
    Entry(word: "你好", syllables: ["ni", "hao"], count: 5),
    Entry(word: "长城", syllables: ["chang", "cheng"]),
  ]
  let data = GooglePinyinUserDict.toGooglePinyinData(entries)
  let expected =
    bomLE
    + "# User dictionary for Google Pinyin Input\n你好\t5\tni hao\n长城\t1\tchang cheng\n"
    .data(using: .utf16LittleEndian)!
  expect(data == expected, "Google format bytes")
  expect(GooglePinyinUserDict.parse(data).entries == entries, "round trip")
}

private func testSyllableTableMatchesLibime() {
  let s = GooglePinyinUserDict.validSyllables
  expect(s.count == 422, "syllable count \(s.count)")
  for syllable in ["a", "zhuang", "lv", "nve", "lve", "er", "ng", "m"] {
    expect(s.contains(syllable), "valid \(syllable)")
  }
  for syllable in ["lue", "nue", "v", "ü", "shix"] {
    expect(!s.contains(syllable), "invalid \(syllable)")
  }
}

private func testParsesEnglishAndTypedCodes() {
  let result = GooglePinyinUserDict.parse(
    googleExport(
      "香港\t907\txg",
      "帮忙\t7\tbang m",
      "app里\t1\t\\0 a p p \\16 li",
      "Android\t449\t\\0 a n d r o i d",
      "pro\t703\t\\0 p r o",
      "Pro\t10\t\\0 p r o",
      "x\t989\t\\0 x",
      "103\t2\t\\300 1 0 3",
      "堡\t0\tbao",
      "香港\t3\txg"))
  expect(
    result.english == [
      .init(word: "Android", count: 449), .init(word: "pro", count: 713),
    ], "english: \(result.english)")
  expect(
    result.typed == [
      .init(code: "xg", word: "香港", count: 910),
      .init(code: "bangm", word: "帮忙", count: 7),
      .init(code: "appli", word: "app里", count: 1),
      .init(code: "android", word: "Android", count: 449),
      .init(code: "pro", word: "pro", count: 703),
      .init(code: "pro", word: "Pro", count: 10),
    ], "typed: \(result.typed)")
}

@main
struct GooglePinyinTests {
  static func main() {
    testParsesGoogleExport()
    testFieldOrderAndSeparatorsAreLenient()
    testSkipsInvalidEntries()
    testDecodesByBomOrFallsBackToGbk()
    testDoesNotMistakeLibimeTextForGoogle()
    testWritesGoogleFormatThatRoundTrips()
    testSyllableTableMatchesLibime()
    testParsesEnglishAndTypedCodes()
    if failures > 0 {
      fatalError("\(failures) Google Pinyin user dictionary tests failed")
    }
    print("Google Pinyin user dictionary tests passed")
  }
}
