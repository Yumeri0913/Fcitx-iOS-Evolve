import Fcitx
import Foundation
import KeyboardUI
import SwiftUtil

/// Merges Google Pinyin words parsed by the main app into pinyin user data
/// (user.dict and user.history), so they rank and keep learning like words fcitx
/// learned itself. User data belongs to the keyboard: merging happens here, only
/// while the pinyin engine does not hold the files.
enum GooglePinyinImport {
  // Keyboard private, so an import downloaded again by Sync config isn't applied twice.
  private static let appliedFile = documents.appendingPathComponent(
    "tmp/googlepinyin-applied.json")

  private static func loadApplied() -> Set<String> {
    guard let data = try? Data(contentsOf: appliedFile),
      let list = try? JSONDecoder().decode([String].self, from: data)
    else {
      return []
    }
    return Set(list)
  }

  private static func markApplied(_ file: URL) {
    var applied = loadApplied()
    applied.insert(file.lastPathComponent)
    mkdirP(appliedFile.deletingLastPathComponent().path)
    if let data = try? JSONEncoder().encode(applied.sorted()) {
      try? data.write(to: appliedFile, options: .atomic)
    }
    if appGroupAvailable {
      let _ = removeFile(file)
    }
  }

  /// import-<UUID>.tsv and clear-<UUID>.flag files not applied yet, oldest first.
  private static func pendingFiles() -> [URL] {
    let applied = loadApplied()
    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: googlePinyinImportDirectory, includingPropertiesForKeys: [.creationDateKey])) ?? []
    return
      files
      .filter {
        (($0.lastPathComponent.hasPrefix("import-") && $0.pathExtension == "tsv")
          || ($0.lastPathComponent.hasPrefix("clear-") && $0.pathExtension == "flag"))
          && !applied.contains($0.lastPathComponent)
      }
      .sorted {
        let a = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
        let b = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
        return a < b
      }
  }

  // viewWillAppear and Sync config may both find the same pending file.
  private static let lock = NSLock()

  private static func isClear(_ file: URL) -> Bool {
    file.lastPathComponent.hasPrefix("clear-")
  }

  private static func apply(
    _ merge: (URL) -> GooglePinyinMergeResult, clear: () -> Bool
  ) -> (Int, Int)? {
    lock.lock()
    defer { lock.unlock() }
    var added = 0
    var existing = 0
    var appliedAny = false
    for file in pendingFiles() {
      if isClear(file) {
        if clear() {
          FCITX_INFO("Cleared pinyin user dictionary")
          markApplied(file)
        }
        continue
      }
      let result = merge(file)
      if result.ok {
        FCITX_INFO(
          "Merged \(file.lastPathComponent): added=\(result.added) existing=\(result.existing) invalid=\(result.invalid)"
        )
        added += Int(result.added)
        existing += Int(result.existing)
        appliedAny = true
        markApplied(file)
      } else {
        FCITX_ERROR("Failed to merge \(file.lastPathComponent)")
      }
    }
    return appliedAny ? (added, existing) : nil
  }

  /// Before startKeyboardFcitx: the engine hasn't read the files yet.
  static func applyBeforeStart() -> (Int, Int)? {
    return apply(
      { mergeGooglePinyinWords($0.path, appGroupData.path) },
      clear: {
        // English words committed with Return are learned words too.
        ["pinyin/user.dict", "pinyin/user.english"].allSatisfy {
          let file = appGroupData.appendingPathComponent($0)
          return !FileManager.default.fileExists(atPath: file.path) || removeFile(file)
        }
      })
  }

  /// With fcitx running: save, merge, then reload the engine's user data.
  static func applyLive() -> (Int, Int)? {
    if pendingFiles().isEmpty {
      return nil
    }
    return apply({ importGooglePinyinWordsLive($0.path) }, clear: { clearPinyinUserDictLive() })
  }

  @MainActor
  static func showResult(_ result: (Int, Int)?) {
    guard let (added, existing) = result else { return }
    vm.showNotice(
      String(
        format: NSLocalizedString("Merged Google Pinyin words: %d new, %d existing", comment: ""),
        added, existing))
  }
}

/// Like InsightKey, save learned words when the keyboard hides instead of relying
/// on the 30 minute auto save, as iOS may kill the extension any time.
@MainActor
enum UserDataSaver {
  private static var lastSave = Date.distantPast

  static func saveIfNeeded() {
    let now = Date()
    if now.timeIntervalSince(lastSave) < 60 {
      return
    }
    lastSave = now
    Fcitx.saveUserData()
  }
}
