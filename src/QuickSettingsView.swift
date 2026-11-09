import Fcitx
import FcitxIpc
import SwiftUI
import SwiftUtil

// Google Pinyin 4.5.2's settings (res/xml/setting_*.xml) that have an fcitx
// equivalent, in the same order and wording, so they can be set in one place.

private let pinyinUri = "fcitx://config/addon/pinyin"
private let uipanelUri = "fcitx://config/addon/uipanel"
private let chttransUri = "fcitx://config/addon/chttrans"

/// Fuzzy pinyin pairs Google Pinyin offers (k = g has no fcitx equivalent) and whether
/// Google Pinyin turns them on with the master switch.
private let fuzzyPairs: [(option: String, label: String, googleDefault: Bool)] = [
  ("Z_ZH", "z = zh", true),
  ("C_CH", "c = ch", true),
  ("S_SH", "s = sh", true),
  ("AN_ANG", "an = ang", true),
  ("EN_ENG", "en = eng", true),
  ("IN_ING", "in = ing", true),
  ("L_N", "l = n", false),
  ("F_H", "f = h", false),
  ("L_R", "r = l", false),
  ("IAN_IANG", "ian = iang", false),
  ("UAN_UANG", "uan = uang", false),
]

/// Google Pinyin's 拼音方案: full pinyin or a shuangpin profile.
private let pinyinSchemes: [(value: String, label: String)] = [
  ("", "Full pinyin"),
  ("MS", "Shuangpin - Microsoft"),
  ("Ziguang", "Shuangpin - Ziguang"),
  ("PinyinJiajia", "Shuangpin - Pinyin Jiajia"),
  ("ABC", "Shuangpin - ABC"),
  ("Ziranma", "Shuangpin - Ziranma"),
  ("Xiaohe", "Shuangpin - Xiaohe"),
]

/// Value of an option in getConfig()'s spec tree, e.g. path "Fuzzy/Z_ZH".
private func optionValue(_ config: [String: Any], _ path: String) -> String? {
  var node = config
  for part in path.split(separator: "/") {
    guard let children = node["Children"] as? [[String: Any]],
      let child = children.first(where: { $0["Option"] as? String == String(part) })
    else {
      return nil
    }
    node = child
  }
  return node["Value"] as? String
}

/// chttrans' EnabledIM is hidden from getConfig, so read its ini file.
private func chttransEnabledIMs() -> [String] {
  let file = appGroupConfig.appendingPathComponent("conf/chttrans.conf")
  guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
  var inSection = false
  var result = [String]()
  for line in text.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
    if line.hasPrefix("[") {
      inSection = line == "[EnabledIM]"
    } else if inSection, let eq = line.firstIndex(of: "="), !line.hasPrefix("#") {
      result.append(String(line[line.index(after: eq)...]))
    }
  }
  return result
}

private func enabledInputMethodNames() -> [String] {
  deserialize([InputMethod].self, String(getInputMethods())).map { $0.name }
}

private func saveInputMethods(_ names: [String]) {
  setInputMethods(String(data: try! JSONEncoder().encode(names), encoding: .utf8)!)
  requestReload()
}

@MainActor
private final class QuickSettings: ObservableObject {
  @Published var pinyin = [String: Any]()
  @Published var uipanel = [String: Any]()
  @Published var traditional = false
  @Published var scheme = ""
  @Published var hasShuangpin = false

  func reload() {
    pinyin = getConfig(pinyinUri)
    uipanel = getConfig(uipanelUri)
    let ims = enabledInputMethodNames()
    hasShuangpin = deserialize([InputMethod].self, String(getAllInputMethods())).contains {
      $0.name == "shuangpin"
    }
    traditional = chttransEnabledIMs().contains { $0 == "pinyin" || $0 == "shuangpin" }
    if ims.contains("shuangpin") && !ims.contains("pinyin") {
      scheme = optionValue(pinyin, "ShuangpinProfile") ?? "MS"
    } else {
      scheme = ""
    }
  }

  func pinyinBool(_ path: String) -> Binding<Bool> {
    boolBinding(path, uri: pinyinUri, config: \.pinyin)
  }

  func uipanelBool(_ path: String) -> Binding<Bool> {
    boolBinding(path, uri: uipanelUri, config: \.uipanel)
  }

  private func boolBinding(
    _ path: String, uri: String, config: ReferenceWritableKeyPath<QuickSettings, [String: Any]>
  ) -> Binding<Bool> {
    Binding(
      get: { optionValue(self[keyPath: config], path) == "True" },
      set: { value in
        self.write(uri, path, value ? "True" : "False")
        self[keyPath: config] = getConfig(uri)
      })
  }

  func uipanelValue(_ path: String) -> Binding<String> {
    Binding(
      get: { optionValue(self.uipanel, path) ?? "" },
      set: { value in
        self.write(uipanelUri, path, value)
        self.uipanel = getConfig(uipanelUri)
      })
  }

  /// Write one option given as "Group/Option" with a string value.
  func write(_ uri: String, _ path: String, _ value: String) {
    var object: Any = value
    for part in path.split(separator: "/").reversed() {
      object = [String(part): object]
    }
    setConfig(uri, "", object)
  }

  var correction: Binding<Bool> {
    Binding(
      get: { (optionValue(self.pinyin, "Fuzzy/Correction") ?? "None") != "None" },
      set: { value in
        // Google Pinyin's 智能更正: keyboard correction priced by touch position.
        self.write(pinyinUri, "Fuzzy/Correction", value ? "QWERTY" : "None")
        self.write(uipanelUri, "TouchCorrection", value ? "True" : "False")
        self.pinyin = getConfig(pinyinUri)
        self.uipanel = getConfig(uipanelUri)
      })
  }

  /// Google Pinyin's master switch: on applies its default pairs, off clears all.
  var fuzzy: Binding<Bool> {
    Binding(
      get: { fuzzyPairs.contains { optionValue(self.pinyin, "Fuzzy/\($0.option)") == "True" } },
      set: { value in
        var pairs = [String: String]()
        for pair in fuzzyPairs {
          pairs[pair.option] = value && pair.googleDefault ? "True" : "False"
        }
        setConfig(pinyinUri, "", ["Fuzzy": pairs])
        self.pinyin = getConfig(pinyinUri)
      })
  }

  var traditionalBinding: Binding<Bool> {
    Binding(
      get: { self.traditional },
      set: { value in
        let others = chttransEnabledIMs().filter { $0 != "pinyin" && $0 != "shuangpin" }
        let ims = value ? others + ["pinyin", "shuangpin"] : others
        var list = [String: String]()
        for (i, im) in ims.enumerated() {
          list[String(i)] = im
        }
        setConfig(chttransUri, "", ["EnabledIM": list])
        self.traditional = value
      })
  }

  var schemeBinding: Binding<String> {
    Binding(
      get: { self.scheme },
      set: { value in
        var ims = enabledInputMethodNames()
        let target = value.isEmpty ? "pinyin" : "shuangpin"
        if let index = ims.firstIndex(where: { $0 == "pinyin" || $0 == "shuangpin" }) {
          ims[index] = target
          ims.removeAll { ($0 == "pinyin" || $0 == "shuangpin") && $0 != target }
        } else {
          ims.insert(target, at: 0)
        }
        if !value.isEmpty {
          self.write(pinyinUri, "ShuangpinProfile", value)
        }
        saveInputMethods(ims)
        self.scheme = value
      })
  }
}

struct QuickSettingsView: View {
  @StateObject private var settings = QuickSettings()
  @State private var showClearConfirm = false

  var body: some View {
    Form {
      Section {
        Toggle(
          "Double space inserts a period", isOn: settings.uipanelBool("DoubleSpacePeriod"))
      } header: {
        Text("Input")
      }

      Section {
        // Builds with PINYIN_ONLY have no shuangpin.
        if settings.hasShuangpin {
          Picker("Pinyin scheme", selection: settings.schemeBinding) {
            ForEach(pinyinSchemes, id: \.value) { scheme in
              Text(NSLocalizedString(scheme.label, comment: "")).tag(scheme.value)
            }
          }
        }
        Toggle("Traditional Chinese", isOn: settings.traditionalBinding)
        Toggle("Suggest English words", isOn: settings.pinyinBool("SpellEnabled"))
        Toggle("Chinese prediction", isOn: settings.pinyinBool("Prediction"))
        // Off like Google Pinyin: v stays pinyin, so vpn, vip, vivo are typed like any word.
        Toggle("V triggers quick phrase", isOn: settings.pinyinBool("VAsQuickphrase"))
        Toggle("Smart correction", isOn: settings.correction)
        Toggle("Fuzzy pinyin", isOn: settings.fuzzy)
        NavigationLink {
          FuzzyPinyinView(settings: settings)
        } label: {
          Text("Fuzzy pinyin settings")
        }
      } header: {
        Text("Chinese input")
      }

      Section {
        Picker("Theme style", selection: settings.uipanelValue("ThemeStyle")) {
          Text("iOS").tag("iOS")
          Text("Google Pinyin").tag("Google Pinyin")
        }
        Picker("Theme", selection: settings.uipanelValue("Theme")) {
          Text("Follow system").tag("Follow system")
          Text("Light").tag("Light")
          Text("Dark").tag("Dark")
        }
        Picker("Key border", selection: settings.uipanelValue("KeyBorder")) {
          Text("Follow theme style").tag("Follow theme style")
          Text("On").tag("On")
          Text("Off").tag("Off")
        }
        Toggle("Show key preview on keypress", isOn: settings.uipanelBool("KeyPopup"))
        Toggle("Vibrate on keypress", isOn: settings.uipanelBool("Vibrate"))
        Picker("Vibration strength", selection: settings.uipanelValue("VibrationStrength")) {
          Text("Weak").tag("Weak")
          Text("Medium").tag("Medium")
          Text("Strong").tag("Strong")
        }
        .disabled(!settings.uipanelBool("Vibrate").wrappedValue)
        Picker("Keyboard height", selection: settings.uipanelValue("HeightMode")) {
          Text("Same as Google Pinyin").tag("Same as Google Pinyin")
          Text("Percentage of screen height").tag("Percentage of screen height")
        }
        // Google Pinyin's 键盘高度 steps.
        Picker("Keyboard height ratio", selection: settings.uipanelValue("HeightRatio")) {
          Text("Low").tag("90")
          Text("Medium low").tag("95")
          Text("Normal").tag("100")
          Text("Medium high").tag("105")
          Text("High").tag("110")
        }
        Picker("Swipe input sensitivity", selection: settings.uipanelValue("SlideSensitivity")) {
          Text("Low").tag("Low")
          Text("Medium low").tag("Medium low")
          Text("Normal").tag("Normal")
          Text("Medium high").tag("Medium high")
          Text("High").tag("High")
        }
        Picker("Long press delay", selection: settings.uipanelValue("LongPressDelay")) {
          ForEach(["200", "300", "400", "500", "700"], id: \.self) { ms in
            Text("\(ms) ms").tag(ms)
          }
        }
      } header: {
        Text("Keyboard")
      }

      Section {
        NavigationLink(destination: DataManagerView()) {
          Text("Import or export user dictionary")
        }
        Button(role: .destructive) {
          showClearConfirm = true
        } label: {
          Text("Clear user dictionary")
        }
      } header: {
        Text("Dictionary")
      }
    }
    .navigationTitle(NSLocalizedString("Quick settings", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { settings.reload() }
    .confirmationDialog(
      NSLocalizedString("Clear words learned while typing?", comment: ""),
      isPresented: $showClearConfirm, titleVisibility: .visible
    ) {
      Button(NSLocalizedString("Clear user dictionary", comment: ""), role: .destructive) {
        GooglePinyinUserDict.requestClear()
      }
    }
  }
}

private struct FuzzyPinyinView: View {
  @ObservedObject var settings: QuickSettings

  var body: some View {
    Form {
      ForEach(fuzzyPairs, id: \.option) { pair in
        Toggle(pair.label, isOn: settings.pinyinBool("Fuzzy/\(pair.option)"))
      }
    }
    .navigationTitle(NSLocalizedString("Fuzzy pinyin settings", comment: ""))
    .navigationBarTitleDisplayMode(.inline)
  }
}
