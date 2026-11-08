import Compression
import Foundation

/// Emoji keyword search over fcitx5's emoji module data (CLDR annotations, zh.dict and
/// en.dict from fcitx5/src/modules/emoji/data), ported from InsightKey's
/// EmojiSearchIndex.kt.
///
/// File format: little endian uint32 uncompressed size, then zlib data containing
/// uint32 emoji count, and for each emoji: string emoji, uint32 annotation count, strings.
/// Strings are uint32 length + UTF-8 bytes.
struct EmojiSearchIndex {
  /// Emojis in data order (CLDR order, roughly by popularity within groups).
  let emojis: [String]
  /// Lower case annotation -> indexes into emojis.
  let annotations: [String: [Int]]

  /// Emojis matching the query, best first: annotation equal to the query, then
  /// annotations starting with it, then containing it; ties keep data order.
  func search(_ query: String, limit: Int = 64) -> [String] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    if q.isEmpty {
      return []
    }
    var best = [Int: Int]()
    for (annotation, indexes) in annotations {
      let rank: Int
      if annotation == q {
        rank = 0
      } else if annotation.hasPrefix(q) {
        rank = 1
      } else if annotation.contains(q) {
        rank = 2
      } else {
        continue
      }
      for i in indexes {
        best[i] = min(best[i] ?? rank, rank)
      }
    }
    return best.sorted { ($0.value, $0.key) < ($1.value, $1.key) }
      .prefix(limit).map { emojis[$0.key] }
  }

  static func parse(_ data: Data) -> EmojiSearchIndex? {
    guard data.count > 6 else { return nil }
    let bytes = [UInt8](data)
    let expected = Int(
      UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
    // Skip the 2 byte zlib header: COMPRESSION_ZLIB is raw deflate.
    var output = [UInt8](repeating: 0, count: expected)
    let n = bytes[6...].withUnsafeBufferPointer { src in
      compression_decode_buffer(
        &output, expected, src.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
    }
    guard n == expected else { return nil }
    var offset = 0
    func uint32() -> Int? {
      guard offset + 4 <= output.count else { return nil }
      let v =
        UInt32(output[offset]) | UInt32(output[offset + 1]) << 8
        | UInt32(output[offset + 2]) << 16 | UInt32(output[offset + 3]) << 24
      offset += 4
      return Int(v)
    }
    func string() -> String? {
      guard let len = uint32(), offset + len <= output.count else { return nil }
      let s = String(decoding: output[offset..<offset + len], as: UTF8.self)
      offset += len
      return s
    }
    guard let count = uint32() else { return nil }
    var emojis = [String]()
    var annotations = [String: [Int]]()
    for index in 0..<count {
      guard let emoji = string(), let annotationCount = uint32() else { return nil }
      emojis.append(emoji)
      for _ in 0..<annotationCount {
        guard let annotation = string() else { return nil }
        annotations[annotation.lowercased(), default: []].append(index)
      }
    }
    return EmojiSearchIndex(emojis: emojis, annotations: annotations)
  }
}

/// Chinese and English annotations together, Chinese results first.
enum EmojiSearcher {
  private static let indexes: [EmojiSearchIndex] = ["zh", "en"].compactMap { language in
    let url = Bundle.main.bundleURL.appendingPathComponent("share/emoji/\(language).dict")
    return (try? Data(contentsOf: url)).flatMap(EmojiSearchIndex.parse)
  }

  static func search(_ query: String, limit: Int = 64) -> [String] {
    var result = [String]()
    var seen = Set<String>()
    for index in indexes {
      for emoji in index.search(query, limit: limit) where seen.insert(emoji).inserted {
        result.append(emoji)
      }
      if result.count >= limit {
        break
      }
    }
    return Array(result.prefix(limit))
  }
}
