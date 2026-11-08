import Foundation

/// Reader/writer for the user dictionary text file exported by Google Pinyin for Android
/// (Settings › Dictionary › Export user dictionary, `GooglePinyinInput/user-dictionary.txt`),
/// and converter from/to libime's text dictionary format. Ported from InsightKey's
/// `GooglePinyinUserDict.kt` so both platforms accept and produce the same files.
///
/// Google Pinyin export format:
/// - UTF-16LE with BOM, `\n` line endings
/// - first line `# User dictionary for Google Pinyin Input`
/// - one entry per line: `word<TAB>count<TAB>pin yin[<TAB>tx=N]`
/// - English entries mark their tokens with a language marker, e.g. `hello\t3\t\0 hello`
///
/// Google Pinyin's importer is lenient: BOM decides the charset (GBK without BOM), lines
/// starting with `#` or `;` are comments, fields are separated by TAB (or a single space when
/// the line has no TAB), and the order of the first three fields does not matter.
///
/// libime text format: `word pin'yin [cost]`, separated by whitespace.
enum GooglePinyinUserDict {
  static let header = "# User dictionary for Google Pinyin Input"
  static let defaultFileName = "user-dictionary.txt"

  struct Entry: Equatable {
    let word: String
    let syllables: [String]
    var count = 1

    var libimePinyin: String { syllables.joined(separator: "'") }
    var googlePinyin: String { syllables.joined(separator: " ") }
  }

  struct ParseResult {
    let entries: [Entry]
    /// Non-comment lines that could not be converted (English words, invalid pinyin…).
    let skipped: Int
  }

  /// Full pinyin syllables accepted by libime without fuzzy flags.
  static let validSyllables: Set<String> = Set(
    """
    a ai an ang ao ba bai ban bang bao bei ben beng bi bian biang biao bie bin bing bo bong bu \
    ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu \
    chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao \
    de dei den deng di dia dian diao die din ding diu dong dou du duan dui dun duo e ei en eng \
    er fa fan fang fei fen feng fiao fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu \
    gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hong hou hu hua huai \
    huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun ka kai \
    kan kang kao ke kei ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai lan lang lao \
    le lei leng li lia lian liang liao lie lin ling liu lo long lou lu luan lun luo lv lve m ma \
    mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu n na nai nan nang \
    nao ne nei nen neng ng ni nia nian niang niao nie nin ning niu nong nou nu nuan nun nuo nv \
    nve o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi qia qian \
    qiang qiao qie qin qing qiong qiu qu quan que qun r ran rang rao re ren reng ri rong rou ru \
    rua ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao she shei shen \
    sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ta \
    tai tan tang tao te tei teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa wai wan \
    wang wei wen weng wo wong wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun \
    ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze zei zen \
    zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang \
    zhui zhun zhuo zi zong zou zu zuan zui zun zuo
    """.split(separator: " ").map(String.init))

  private static let bomUTF8: [UInt8] = [0xEF, 0xBB, 0xBF]
  private static let bomUTF16LE: [UInt8] = [0xFF, 0xFE]
  private static let bomUTF16BE: [UInt8] = [0xFE, 0xFF]

  private static let pinyinRegex = try! NSRegularExpression(
    pattern: "^'?[a-z\u{00fc}]+(?:[ '|][a-z\u{00fc}]+)*'?$")
  private static let countRegex = try! NSRegularExpression(pattern: "^[0-9]+,?$")
  private static let englishRegex = try! NSRegularExpression(
    pattern: "^[A-Za-z]+(?:[-'][A-Za-z]+)*$")
  private static let languageMarkerRegex = try! NSRegularExpression(pattern: "\\\\[0-9]+")

  private static func matches(_ regex: NSRegularExpression, _ s: String) -> Bool {
    regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }

  private static func startsWith(_ data: Data, _ prefix: [UInt8]) -> Bool {
    data.count >= prefix.count && Array(data.prefix(prefix.count)) == prefix
  }

  /// Decode bytes the same way Google Pinyin does: by BOM, falling back to UTF-8 if the
  /// content is valid UTF-8, otherwise GBK (Google Pinyin's default without BOM).
  static func decode(_ data: Data) -> String {
    if startsWith(data, bomUTF16LE) {
      return String(data: data.dropFirst(2), encoding: .utf16LittleEndian) ?? ""
    }
    if startsWith(data, bomUTF16BE) {
      return String(data: data.dropFirst(2), encoding: .utf16BigEndian) ?? ""
    }
    if startsWith(data, bomUTF8) {
      return String(data: data.dropFirst(3), encoding: .utf8) ?? ""
    }
    if let text = String(data: data, encoding: .utf8) {
      return text
    }
    let gb18030 = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    return String(data: data, encoding: gb18030) ?? ""
  }

  private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x3007,  // 〇
      0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
      0x20000...0x323AF, 0x2F800...0x2FA1F:
      return true
    default:
      return false
    }
  }

  private static func hanLength(_ s: String) -> Int? {
    var n = 0
    for scalar in s.unicodeScalars {
      if !isHan(scalar) {
        return nil
      }
      n += 1
    }
    return n
  }

  /// Normalize one syllable to libime spelling (ü → v, lue/nue → lve/nve).
  static func normalizeSyllable(_ s: String) -> String {
    let v = s.lowercased().replacingOccurrences(of: "\u{00fc}", with: "v")
    switch v {
    case "lue": return "lve"
    case "nue": return "nve"
    default: return v
    }
  }

  private static func lines(_ text: String) -> [String] {
    text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}\r\n")) }
  }

  private static func parseLine(_ line: String) -> Entry? {
    let fields =
      line.contains("\t")
      ? line.split(separator: "\t", omittingEmptySubsequences: false)
      : line.split(separator: " ", omittingEmptySubsequences: false)
    var word: String?
    var pinyin: String?
    var count: Int?
    var other: String?
    for f in fields.prefix(3) {
      let field = f.trimmingCharacters(in: .whitespaces)
      if field.isEmpty {
        continue
      }
      // Language markers like "\0" mean English (or mixed) tokens: not for pinyin.
      if matches(languageMarkerRegex, field) {
        return nil
      }
      if field.unicodeScalars.contains(where: isHan) {
        word = field
      } else if pinyin == nil && matches(pinyinRegex, field) {
        pinyin = field
      } else if matches(countRegex, field) {
        count = max(1, Int(field.trimmingCharacters(in: CharacterSet(charactersIn: ","))) ?? 1)
      } else if matches(englishRegex, field) {
        return nil
      } else {
        other = field
      }
    }
    guard let w = word ?? other, let p = pinyin else {
      return nil
    }
    let syllables = p.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
      .split(whereSeparator: { $0 == " " || $0 == "'" || $0 == "|" })
      .map { normalizeSyllable(String($0)) }
    if syllables.isEmpty || syllables.contains(where: { !validSyllables.contains($0) }) {
      return nil
    }
    if hanLength(w) != syllables.count {
      return nil
    }
    return Entry(word: w, syllables: syllables, count: count ?? 1)
  }

  /// Whether the bytes look like a Google Pinyin user dictionary rather than a libime text
  /// dictionary: either UTF-16 BOM, the export header, or TAB separated `word count pinyin`.
  static func looksLikeGooglePinyin(_ data: Data) -> Bool {
    if startsWith(data, bomUTF16LE) || startsWith(data, bomUTF16BE) {
      return true
    }
    let nonEmpty = lines(decode(data)).filter {
      !$0.trimmingCharacters(in: .whitespaces).isEmpty
    }.prefix(50)
    if nonEmpty.contains(where: { $0.hasPrefix(header) }) {
      return true
    }
    let entries = nonEmpty.filter { !$0.hasPrefix("#") && !$0.hasPrefix(";") }
    if entries.isEmpty {
      return false
    }
    let tabSeparated = entries.filter { line in
      let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
      return fields.count >= 3
        && fields.prefix(3).contains {
          matches(countRegex, $0.trimmingCharacters(in: .whitespaces))
        }
    }
    return tabSeparated.count * 2 > entries.count
  }

  /// Parse a Google Pinyin user dictionary, merging duplicates by keeping the higher count.
  static func parse(_ data: Data) -> ParseResult {
    parse(decode(data))
  }

  static func parse(_ text: String) -> ParseResult {
    var order = [String]()
    var merged = [String: Entry]()
    var skipped = 0
    for line in lines(text) {
      if line.trimmingCharacters(in: .whitespaces).isEmpty || line.hasPrefix("#")
        || line.hasPrefix(";")
      {
        continue
      }
      guard let entry = parseLine(line) else {
        skipped += 1
        continue
      }
      let key = entry.word + " " + entry.libimePinyin
      if var old = merged[key] {
        old.count = max(old.count, entry.count)
        merged[key] = old
      } else {
        merged[key] = entry
        order.append(key)
      }
    }
    return ParseResult(entries: order.map { merged[$0]! }, skipped: skipped)
  }

  static func toLibimeText(_ entries: [Entry]) -> String {
    entries.map { "\($0.word) \($0.libimePinyin) 0\n" }.joined()
  }

  private static func unescapeLibimeValue(_ token: String) -> String {
    guard token.count >= 2, token.hasPrefix("\""), token.hasSuffix("\"") else {
      return token
    }
    var result = ""
    var escaping = false
    for c in token.dropFirst().dropLast() {
      if escaping {
        result.append(c == "n" ? "\n" : c)
        escaping = false
      } else if c == "\\" {
        escaping = true
      } else {
        result.append(c)
      }
    }
    return result
  }

  /// Parse libime text dictionary content as produced by `PinyinDictionary::saveText`.
  static func parseLibimeText(_ text: String) -> [Entry] {
    var result = [Entry]()
    for raw in lines(text) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        continue
      }
      var wordToken: String
      var rest: Substring
      if line.hasPrefix("\"") {
        // Quoted word, find the closing quote that is not escaped.
        var index = line.index(after: line.startIndex)
        var closing: String.Index?
        while index < line.endIndex {
          if line[index] == "\\" {
            index = line.index(index, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
          } else if line[index] == "\"" {
            closing = index
            break
          } else {
            index = line.index(after: index)
          }
        }
        guard let closing else {
          continue
        }
        wordToken = String(line[...closing])
        rest = line[line.index(after: closing)...]
      } else {
        guard let space = line.firstIndex(where: { $0.isWhitespace }) else {
          continue
        }
        wordToken = String(line[..<space])
        rest = line[space...]
      }
      guard let pinyin = rest.split(whereSeparator: { $0.isWhitespace }).first else {
        continue
      }
      let word = unescapeLibimeValue(wordToken)
      let syllables = pinyin.split(separator: "'").map(String.init)
      if word.isEmpty || syllables.isEmpty {
        continue
      }
      result.append(Entry(word: word, syllables: syllables))
    }
    return result
  }

  /// Serialize entries to Google Pinyin user dictionary bytes (UTF-16LE with BOM).
  static func toGooglePinyinData(_ entries: [Entry]) -> Data {
    var text = header + "\n"
    for entry in entries {
      text += "\(entry.word)\t\(max(1, entry.count))\t\(entry.googlePinyin)\n"
    }
    return Data(bomUTF16LE) + (text.data(using: .utf16LittleEndian) ?? Data())
  }
}
