import Fcitx
import FcitxIpc
import Foundation
import SwiftUtil

enum GooglePinyinDictError: Error {
  case noEntry
  case noSnapshot
  case readFailed
}

/// The main app only parses and formats files. Pinyin user data belongs to the Chinese
/// keyboard, which merges imports (keyboard/GooglePinyinImport.swift) and provides
/// the words to export.
extension GooglePinyinUserDict {
  /// Without App Group: the keyboard uploads its user words during Sync config.
  static let keyboardWordsSnapshot = documents.appendingPathComponent(
    "tmp/googlepinyin/keyboard-words.tsv")

  /// "word\tpin'yin\tcount" lines, the format of googlepinyin::toTsv / fromTsv.
  static func toTsv(_ entries: [Entry]) -> String {
    entries.map { "\($0.word)\t\($0.libimePinyin)\t\($0.count)\n" }.joined()
  }

  static func fromTsv(_ tsv: String) -> [Entry] {
    tsv.split(separator: "\n").compactMap { line in
      let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
      guard fields.count >= 3, !fields[0].isEmpty, !fields[1].isEmpty else { return nil }
      return Entry(
        word: String(fields[0]),
        syllables: fields[1].split(separator: "'").map(String.init),
        count: max(1, Int(fields[2]) ?? 1))
    }
  }

  /// Parse a Google Pinyin user dictionary and hand it to the keyboard as
  /// import-<UUID>.tsv. The UUID keeps the keyboard from applying it twice.
  static func importFile(_ url: URL) throws -> ParseResult {
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped {
        url.stopAccessingSecurityScopedResource()
      }
    }
    let parsed = parse(try Data(contentsOf: url))
    if parsed.entries.isEmpty && parsed.english.isEmpty && parsed.typed.isEmpty {
      throw GooglePinyinDictError.noEntry
    }
    mkdirP(googlePinyinImportDirectory.path)
    let base = googlePinyinImportDirectory.appendingPathComponent("import-\(UUID().uuidString)")
    // English words and what was typed for each word go next to the pinyin words, merged
    // by the keyboard together with them (googlepinyin_runtime.cpp)
    try parsed.typed.map { "\($0.code)\t\($0.word)\t\($0.count)\n" }.joined()
      .write(to: base.appendingPathExtension("typed"), atomically: true, encoding: .utf8)
    try parsed.english.map { "\($0.word)\t\($0.count)\n" }.joined()
      .write(to: base.appendingPathExtension("english"), atomically: true, encoding: .utf8)
    try toTsv(parsed.entries).write(
      to: base.appendingPathExtension("tsv"), atomically: true, encoding: .utf8)
    return parsed
  }

  /// User data belongs to the keyboard, so ask it to clear the words it learned.
  static func requestClear() {
    mkdirP(googlePinyinImportDirectory.path)
    let file = googlePinyinImportDirectory.appendingPathComponent(
      "clear-\(UUID().uuidString).flag")
    FileManager.default.createFile(atPath: file.path, contents: Data())
    if appGroupAvailable {
      requestReload()
    }
  }

  /// Hand pinyin user data from a backup (<dataHome>/pinyin/user.dict and user.history)
  /// to the keyboard to merge, keeping words it learned since.
  static func importUserData(_ dataHome: URL) {
    let dict = dataHome.appendingPathComponent("pinyin/user.dict")
    guard FileManager.default.fileExists(atPath: dict.path) else { return }
    let file = googlePinyinImportDirectory.appendingPathComponent(
      "import-\(UUID().uuidString).tsv")
    mkdirP(googlePinyinImportDirectory.path)
    if !exportGooglePinyinWords(dataHome.path, file.path) {
      FCITX_ERROR("Failed to read restored pinyin user data")
      try? FileManager.default.removeItem(at: file)
    }
  }

  /// Words to export and when they were taken. With App Group they are read from the
  /// keyboard's files directly (the keyboard saves when hidden); otherwise from the
  /// snapshot uploaded by the last Sync config.
  static func keyboardWords() throws -> ([Entry], Date) {
    if appGroupAvailable {
      let file = FileManager.default.temporaryDirectory.appendingPathComponent(
        "userwords-\(UUID().uuidString).tsv")
      defer { try? FileManager.default.removeItem(at: file) }
      guard exportGooglePinyinWords(appGroupData.path, file.path),
        let tsv = try? String(contentsOf: file, encoding: .utf8)
      else {
        throw GooglePinyinDictError.readFailed
      }
      return (fromTsv(tsv), Date())
    }
    guard let tsv = try? String(contentsOf: keyboardWordsSnapshot, encoding: .utf8) else {
      throw GooglePinyinDictError.noSnapshot
    }
    let date =
      (try? FileManager.default.attributesOfItem(atPath: keyboardWordsSnapshot.path))?[
        .modificationDate] as? Date ?? Date()
    return (fromTsv(tsv), date)
  }

  static func exportFile(to url: URL) throws -> Int {
    let (entries, _) = try keyboardWords()
    try toGooglePinyinData(entries).write(to: url)
    return entries.count
  }
}
