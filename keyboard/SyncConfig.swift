import Fcitx
import KeyboardUI
import SwiftUtil
import UIKit

private actor SyncState {
  static let shared = SyncState()
  var task: Task<Void, Never>?

  func startSync(body: @escaping () async -> Void) async {
    let oldTask = task
    task = Task {
      if let oldTask = oldTask {
        oldTask.cancel()
        await oldTask.value
      }
      await body()
      task = nil
    }
  }
}

// Given /list and [keyboard: Rime], return http://127.0.0.1:32489/list?keyboard=Rime.
private func generateURL(_ path: String, params: [String: String]?) -> URL {
  var components = URLComponents()
  components.scheme = "http"
  components.host = localhostV4
  components.port = Int(syncConfigPort)
  components.path = path
  if let params = params {
    components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
  }
  return components.url!
}

private func listFiles(_ keyboard: String) async -> [[String]]? {
  let url = generateURL("/list", params: ["keyboard": keyboard])
  guard let (data, _) = try? await URLSession.shared.data(from: url),
    let list = try? JSONSerialization.jsonObject(with: data) as? [[String]]
  else {
    return nil
  }
  return list
}

private let checksumsPath = documents.appendingPathComponent("tmp/checksums.json")

private func loadChecksums() -> [String: String] {
  guard let data = try? Data(contentsOf: checksumsPath),
    let checksums = try? JSONSerialization.jsonObject(with: data) as? [String: String]
  else {
    return [:]
  }
  return checksums
}

private func saveChecksums(_ checksums: [String: String]) {
  mkdirP(checksumsPath.deletingLastPathComponent().path)
  guard let data = try? JSONSerialization.data(withJSONObject: checksums) else { return }
  try? data.write(to: checksumsPath)
}

private func downloadFile(_ path: String) async -> Bool {
  let file = documents.appendingPathComponent(path)
  let _ = removeFile(file)
  FileManager.default.createFile(atPath: file.path, contents: nil)
  var offset = 0
  while !Task.isCancelled {
    let url = generateURL("/download", params: ["path": path, "start": String(offset)])
    guard let (chunkData, response) = try? await URLSession.shared.data(from: url),
      let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 || httpResponse.statusCode == 206
    else {
      FCITX_WARN("download \(path) failed")
      return false
    }
    do {
      let handle = try FileHandle(forWritingTo: file)
      defer { try? handle.close() }
      handle.seekToEndOfFile()
      try handle.write(contentsOf: chunkData)
    } catch {
      FCITX_ERROR("write \(path) failed: \(error)")
      return false
    }
    if httpResponse.statusCode == 200 {
      FCITX_INFO("downloaded \(path)")
      return true
    }
    offset += syncConfigChunkSize
  }
  return false
}

// Without App Group the main app can't read the keyboard's pinyin user data, so send
// it a snapshot for exporting as a Google Pinyin user dictionary.
private func uploadGooglePinyinWords() async {
  let file = documents.appendingPathComponent("tmp/googlepinyin-userwords.tsv")
  mkdirP(file.deletingLastPathComponent().path)
  defer { let _ = removeFile(file) }
  guard snapshotGooglePinyinWords(file.path), let data = try? Data(contentsOf: file) else {
    FCITX_ERROR("Failed to snapshot pinyin user words")
    return
  }
  var request = URLRequest(url: generateURL("/googlepinyin/userwords", params: nil))
  request.httpMethod = "POST"
  request.setValue("text/tab-separated-values; charset=utf-8", forHTTPHeaderField: "Content-Type")
  request.httpBody = data
  if let (_, response) = try? await URLSession.shared.data(for: request),
    (response as? HTTPURLResponse)?.statusCode == 200
  {
    FCITX_INFO("Uploaded pinyin user words: \(data.count) bytes")
  } else {
    FCITX_WARN("Upload pinyin user words failed")
  }
}

private func reportDone(_ keyboard: String) async {
  let url = generateURL("/done", params: ["keyboard": keyboard])
  let _ = try? await URLSession.shared.data(from: url)
}

func doSyncConfig(_ keyboard: String) async {
  await SyncState.shared.startSync { [keyboard] in
    while !Task.isCancelled {
      guard let list = await listFiles(keyboard) else {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        continue
      }
      let totalFiles = list.filter { !$0[0].hasSuffix("/") }.count
      Task { @MainActor in
        vm.setSyncProgress(0, totalFiles)
      }
      let checksums = loadChecksums()
      var newChecksums = [String: String]()
      var completedFiles = 0
      for item in list {
        if Task.isCancelled { return }
        let path = item[0]
        if path.hasSuffix("/") {
          let dir = documents.appendingPathComponent(path)
          mkdirP(dir.path)
          FCITX_INFO("mkdir \(dir.path)")
        } else {
          let serverHash = item[1]
          // Also check the file itself: the keyboard may have rewritten it since the
          // last sync (fcitx saves configs from memory), leaving a stale copy.
          let localFile = documents.appendingPathComponent(path)
          if checksums[path] == serverHash
            && FileManager.default.fileExists(atPath: localFile.path)
            && md5Hash(localFile) == serverHash
          {
            FCITX_INFO("skip \(path)")
            newChecksums[path] = serverHash
          } else {
            Task { @MainActor in
              vm.fileInSync = path
            }
            if await downloadFile(path) {
              newChecksums[path] = serverHash
            }
          }
          completedFiles += 1
          let progress = completedFiles
          Task { @MainActor in
            vm.setSyncProgress(progress, totalFiles)
          }
        }
      }
      saveChecksums(newChecksums)
      if keyboard == "Chinese" {
        // Imports arrive as data/googlepinyin/import-<UUID>.tsv.
        let result = GooglePinyinImport.applyLive()
        await MainActor.run { GooglePinyinImport.showResult(result) }
      }
      do {
        try await ClipboardTransport.synchronize(
          store: clipboardStore, endpoint: generateURL("/clipboard/sync", params: nil))
      } catch {
        FCITX_ERROR("Clipboard sync failed: \(error)")
        if Task.isCancelled { return }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        continue
      }
      if Task.isCancelled { return }
      await vm.refreshClipboard()
      // Apply the downloaded config before anything else runs on the fcitx thread.
      reload()
      if keyboard == "Chinese" {
        await uploadGooglePinyinWords()
      }
      await reportDone(keyboard)
      Task { @MainActor in
        vm.setDisplayMode(.syncDone)
        vm.setSyncProgress(0, 0)
      }
      break
    }
  }
}
