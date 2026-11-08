import UIKit

// Key press vibration, like Google Pinyin's 按键振动.
// Keyboard extensions only get haptics with Full Access enabled.
enum VibrationStrength: Int {
  case off = 0
  case light = 1
  case medium = 2
  case heavy = 3
}

@MainActor
enum Haptic {
  private static var generator: UIImpactFeedbackGenerator?

  static func setStrength(_ strength: VibrationStrength) {
    switch strength {
    case .off:
      generator = nil
    case .light:
      generator = UIImpactFeedbackGenerator(style: .light)
    case .medium:
      generator = UIImpactFeedbackGenerator(style: .medium)
    case .heavy:
      generator = UIImpactFeedbackGenerator(style: .heavy)
    }
    generator?.prepare()
  }

  static func keyPress() {
    guard let generator else { return }
    generator.impactOccurred()
    generator.prepare()
  }
}
