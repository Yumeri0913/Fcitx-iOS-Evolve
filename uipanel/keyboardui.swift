import Fcitx
import FcitxProtocol
import SwiftUI
import SwiftUtil
import UIPanel

public func setCandidatesAsync(
  _ program: String, _ inputContext: String, _ auxUp: String, _ preedit: String,
  _ caret: Int32, _ candidates: [String],
  _ highlighted: Int32, _ bulk: Bool, _ hasClientPreedit: Bool, _ tabActionsJSON: String,
  _ hasPrev: Bool, _ hasNext: Bool, _ endReached: Bool
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentProgram(program), inputContextIsFocused(inputContext) else {
      return
    }
    vm.setCandidates(
      inputContext, auxUp, preedit, caret, candidates, highlighted, bulk,
      hasClientPreedit,
      deserialize([CandidateAction].self, tabActionsJSON), hasPrev, hasNext, endReached)
  }
}

public func scrollAsync(
  _ program: String, _ inputContext: String, _ candidates: [String], _ end: Bool
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentProgram(program), inputContextIsFocused(inputContext) else {
      return
    }
    vm.scroll(candidates, end)
  }
}

public func setThemeConfigAsync(_ mode: Int32, _ keyBorder: Bool) {
  DispatchQueue.main.async {
    vm.setThemeConfig(ThemeMode(rawValue: Int(mode)) ?? .followSystem, keyBorder)
  }
}

public func setKeyboardHeightModeAsync(_ mode: Int32) {
  DispatchQueue.main.async {
    vm.setKeyboardHeightMode(KeyboardHeightMode(rawValue: Int(mode)) ?? .googlePinyin)
  }
}

// 0 turns vibration off, 1-3 is light / medium / heavy.
public func setVibrationAsync(_ strength: Int32) {
  DispatchQueue.main.async {
    Haptic.setStrength(VibrationStrength(rawValue: Int(strength)) ?? .off)
  }
}

public struct StatusAreaAction: Identifiable, Sendable {
  public let id: Int32
  let desc: String
  let icon: String
  let checked: Bool
  let separator: Bool
  let children: [StatusAreaAction]

  public init(
    id: Int32, desc: String, icon: String, checked: Bool, separator: Bool,
    children: [StatusAreaAction]
  ) {
    self.id = id
    self.desc = desc
    self.icon = icon
    self.separator = separator
    self.checked = checked
    self.children = children
  }
}

public func setStatusAreaAsync(
  _ program: String, _ inputContext: String, _ actions: [StatusAreaAction]
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentProgram(program), inputContextIsFocused(inputContext) else {
      return
    }
    vm.setStatusArea(inputContext, actions)
  }
}

public func setCurrentInputMethodAsync(
  _ program: String, _ inputContext: String, _ im: String
) {
  DispatchQueue.main.async {
    guard let client, client.isCurrentProgram(program), inputContextIsFocused(inputContext) else {
      return
    }
    vm.setCurrentInputMethod(
      im, deserialize([InputMethod].self, String(getInputMethods())))
  }
}
