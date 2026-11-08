import AlertToast
import FcitxIpc
import SwiftUI
import SwiftUtil
import UIKit
import UniformTypeIdentifiers

private struct ExportedArchive: Identifiable {
  let url: URL
  let id = UUID()
}

// Restored pinyin user data goes through the Google Pinyin merge flow instead of replacing
// the keyboard's files, see GooglePinyinUserDict.importUserData.
private let restoredPinyinUserData = FileManager.default.temporaryDirectory
  .appendingPathComponent("restored-userdata")

private let backupArchive = BackupArchive(
  configDirectory: appGroupConfig,
  dataDirectory: appGroupData,
  databasesDirectory: clipboardDatabases,
  clipboardStore: clipboardStore,
  pinyinUserDataDirectory: restoredPinyinUserData)

private func archiveFileName(_ date: Date) -> String {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "_")
  return "fcitx5-ios_\(timestamp).zip"
}

private func importArchive(from sourceURL: URL, source: ImportSource) throws {
  let scoped = sourceURL.startAccessingSecurityScopedResource()
  defer {
    if scoped {
      sourceURL.stopAccessingSecurityScopedResource()
    }
  }

  try? FileManager.default.removeItem(at: restoredPinyinUserData)
  defer { try? FileManager.default.removeItem(at: restoredPinyinUserData) }
  try backupArchive.importData(from: sourceURL, source: source)
  GooglePinyinUserDict.importUserData(restoredPinyinUserData)
}

struct DataManagerView: View {
  @State private var exporting = false
  @State private var importing = false
  @State private var importSource: ImportSource?
  @State private var showImporter = false
  @State private var importingGooglePinyin = false
  @State private var exportedArchive: ExportedArchive?
  @State private var showToast = false
  @State private var toastMessage = ""
  @State private var toastIcon = "success"
  @State private var exportTask: Task<Void, Never>?
  @State private var importTask: Task<Void, Never>?
  // Cleanup test procedure (each case should see file disappears in the end):
  // 0. Open the FileManager.default.temporaryDirectory (Documents/../tmp) on macOS.
  // 1. Click export, back immediately.
  // 2. Click export, swipe down sheet.
  // 3. Click export, close sheet.
  // 4. Click export, save.
  @State private var currentExportURL: URL?

  private func displayToast(_ message: String, icon: String) {
    toastMessage = message
    toastIcon = icon
    showToast = true
  }

  private func exportData() {
    guard !exporting && !importing else {
      return
    }
    let date = Date()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(archiveFileName(date))
    currentExportURL = url
    exporting = true
    exportTask = Task.detached(priority: .userInitiated) {
      do {
        try backupArchive.export(to: url, date: date)
        guard !Task.isCancelled else {
          try? FileManager.default.removeItem(at: url)
          return
        }
        await MainActor.run {
          exporting = false
          exportedArchive = ExportedArchive(url: url)
        }
      } catch {
        await MainActor.run {
          exporting = false
          displayToast(NSLocalizedString("Export failed", comment: ""), icon: "error")
        }
      }
    }
  }

  private func displayImporter(source: ImportSource) {
    guard !exporting && !importing else {
      return
    }
    importSource = source
    importingGooglePinyin = false
    showImporter = true
  }

  private func displayGooglePinyinImporter() {
    guard !exporting && !importing else {
      return
    }
    importSource = nil
    importingGooglePinyin = true
    showImporter = true
  }

  private func importGooglePinyin(from url: URL) {
    importing = true
    importTask = Task.detached(priority: .userInitiated) {
      do {
        let result = try GooglePinyinUserDict.importFile(url)
        await MainActor.run {
          importing = false
          if appGroupAvailable {
            requestReload()
          }
          let parsed = String(
            format: NSLocalizedString("Parsed %d words, skipped %d lines", comment: ""),
            result.entries.count, result.skipped)
          let next =
            appGroupAvailable
            ? NSLocalizedString("Applied when the keyboard shows next.", comment: "")
            : NSLocalizedString("Sync config to apply.", comment: "")
          displayToast(parsed + "\n" + next, icon: "success")
        }
      } catch GooglePinyinDictError.noEntry {
        await MainActor.run {
          importing = false
          displayToast(
            NSLocalizedString("No pinyin words found", comment: ""), icon: "error")
        }
      } catch {
        FCITX_ERROR("Failed to import Google Pinyin user dictionary: \(error)")
        await MainActor.run {
          importing = false
          displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
        }
      }
    }
  }

  private func exportGooglePinyin() {
    guard !exporting && !importing else {
      return
    }
    // Google Pinyin imports the file by this name.
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    mkdirP(directory.path)
    let url = directory.appendingPathComponent(GooglePinyinUserDict.defaultFileName)
    currentExportURL = url
    exporting = true
    exportTask = Task.detached(priority: .userInitiated) {
      do {
        let count = try GooglePinyinUserDict.exportFile(to: url)
        await MainActor.run {
          exporting = false
          if count == 0 {
            displayToast(NSLocalizedString("No pinyin words found", comment: ""), icon: "error")
          } else {
            exportedArchive = ExportedArchive(url: url)
          }
        }
      } catch GooglePinyinDictError.noSnapshot {
        await MainActor.run {
          exporting = false
          displayToast(
            NSLocalizedString("Sync config first to get words from the keyboard.", comment: ""),
            icon: "error")
        }
      } catch {
        await MainActor.run {
          exporting = false
          displayToast(NSLocalizedString("Export failed", comment: ""), icon: "error")
        }
      }
    }
  }

  private var googlePinyinFooter: String {
    var text = NSLocalizedString(
      "Words in user-dictionary.txt exported from Google Pinyin for Android are merged into the words the keyboard learned, and keep learning as you type. Export includes all of them with their usage counts.",
      comment: "")
    if !appGroupAvailable {
      if let date =
        (try? FileManager.default.attributesOfItem(
          atPath: GooglePinyinUserDict.keyboardWordsSnapshot.path))?[.modificationDate] as? Date
      {
        text +=
          "\n"
          + String(
            format: NSLocalizedString(
              "Export uses words from the last Sync config at %@.", comment: ""),
            date.formatted(date: .abbreviated, time: .shortened))
      } else {
        text +=
          "\n" + NSLocalizedString("Sync config first to get words from the keyboard.", comment: "")
      }
    }
    return text
  }

  private func importData(from url: URL, source: ImportSource) {
    importing = true
    importTask = Task.detached(priority: .userInitiated) {
      do {
        try importArchive(from: url, source: source)
        try Task.checkCancellation()
        await MainActor.run {
          importing = false
          requestReload()
          displayToast(NSLocalizedString("Import succeeded", comment: ""), icon: "success")
        }
      } catch is CancellationError {
        await MainActor.run {
          importing = false
        }
      } catch is InvalidZipError {
        await MainActor.run {
          importing = false
          displayToast(NSLocalizedString("Invalid zip", comment: ""), icon: "error")
        }
      } catch {
        await MainActor.run {
          importing = false
          displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
        }
      }
    }
  }

  var body: some View {
    Form {
      Section {
        Button {
          displayImporter(source: .fcitx5)
        } label: {
          Text("Fcitx5 Android/iOS/macOS")
        }
        .disabled(exporting || importing)
        Button {
          displayImporter(source: .hamster)
        } label: {
          Text("Hamster")
        }
        .disabled(exporting || importing)
      } header: {
        Text("Import data from …").textCase(nil)
      }

      Section {
        Button {
          exportData()
        } label: {
          Text("Fcitx5 Android/iOS/macOS")
        }
        .disabled(exporting || importing)
      } header: {
        Text("Export data to …").textCase(nil)
      }

      Section {
        Button {
          displayGooglePinyinImporter()
        } label: {
          Text("Import Google Pinyin user dictionary")
        }
        .disabled(exporting || importing)
        Button {
          exportGooglePinyin()
        } label: {
          Text("Export as Google Pinyin user dictionary")
        }
        .disabled(exporting || importing)
      } header: {
        Text("Google Pinyin").textCase(nil)
      } footer: {
        Text(googlePinyinFooter)
      }
    }
    .navigationTitle(NSLocalizedString("Data Manager", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .fileImporter(
      isPresented: $showImporter,
      allowedContentTypes: importingGooglePinyin ? [.plainText, .text, .data] : [.zip]
    ) { result in
      if importingGooglePinyin {
        importingGooglePinyin = false
        switch result {
        case .success(let url):
          importGooglePinyin(from: url)
        case .failure(let error):
          if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
            return
          }
          displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
        }
        return
      }
      guard let source = importSource else {
        return
      }
      importSource = nil
      switch result {
      case .success(let url):
        importData(from: url, source: source)
      case .failure(let error):
        if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
          return
        }
        displayToast(NSLocalizedString("Import failed", comment: ""), icon: "error")
      }
    }
    .sheet(
      item: $exportedArchive,
      onDismiss: {
        if let url = currentExportURL {
          try? FileManager.default.removeItem(at: url)
          currentExportURL = nil
        }
      }
    ) { archive in
      ActivityView(activityItems: [archive.url]) { completed in
        // This callback doesn't execute if the sheet is swiped down, so can't rely on remove here.
        exportedArchive = nil
        if completed {
          displayToast(NSLocalizedString("Export succeeded", comment: ""), icon: "success")
        }
      }
    }
    .toast(isPresenting: $showToast) {
      AlertToast(
        displayMode: .alert,
        type: toastIcon == "error" ? .error(Color.red) : .complete(Color.green),
        subTitle: toastMessage,
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .toast(isPresenting: $exporting) {
      AlertToast(
        displayMode: .alert,
        type: .loading,
        subTitle: NSLocalizedString("Exporting", comment: ""),
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .toast(isPresenting: $importing) {
      AlertToast(
        displayMode: .alert,
        type: .loading,
        subTitle: NSLocalizedString("Importing", comment: ""),
        style: AlertToast.AlertStyle.style(subTitleFont: Font.system(size: 20)))
    }
    .onDisappear {
      exportTask?.cancel()
      importTask?.cancel()
      if let url = currentExportURL {
        try? FileManager.default.removeItem(at: url)
        currentExportURL = nil
      }
    }
  }
}
