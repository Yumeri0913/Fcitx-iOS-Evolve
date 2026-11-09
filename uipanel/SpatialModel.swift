import CoreGraphics
import Foundation

/// Keys a touch may have meant: the touched key first, then neighbors by score, as
/// (key, natural log likelihood). Passed to libime's PinyinContext::KeyAlternatives.
struct KeyAlternatives: Equatable {
  let keys: [Character]
  let scores: [Float]
}

/// Touch spatial model, the same one Google Pinyin 4.x uses for its "intelligent
/// correction", ported from InsightKey's SpatialModel.kt: every key is a 2D Gaussian
/// centered on its cell, with a variance that grows with key size. For one touch,
/// the touched key and nearby keys are scored by the log density at the touch point.
///
/// One change from Google: the vertical variance grows at least with the key aspect
/// ratio (varY >= varX * (h / w)^2). Google's formula fits keys about as tall as wide;
/// for keys about 1.4 times as tall, a touch some way into the row above or below cost
/// much more than the same miss into a left or right neighbor, so vertical typos were
/// rarely corrected.
///
/// Coordinates are points of one view; [pointsPerMillimeter] converts them to mm.
struct SpatialModel {
  struct Key {
    let char: Character
    let rect: CGRect

    /// Distance from a point to this rectangle, 0 if inside.
    func distance(to point: CGPoint) -> CGFloat {
      let dx = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
      let dy = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
      return (dx * dx + dy * dy).squareRoot()
    }
  }

  /// UIKit points on iPhone are about 163 per inch.
  static let iPhonePointsPerMillimeter: CGFloat = 163 / 25.4
  private static let neighborFactor: CGFloat = 1.2

  let keys: [Key]
  let pointsPerMillimeter: CGFloat
  /// Neighborhood radius: the smaller of the most common key width and height.
  private let radius: CGFloat

  init(keys: [Key], pointsPerMillimeter: CGFloat = SpatialModel.iPhonePointsPerMillimeter) {
    self.keys = keys
    self.pointsPerMillimeter = pointsPerMillimeter
    func mostCommon(_ values: [CGFloat]) -> CGFloat {
      var counts = [Int: Int]()
      for value in values {
        counts[Int(value), default: 0] += 1
      }
      return CGFloat(counts.max { $0.value < $1.value }?.key ?? 0)
    }
    radius = min(mostCommon(keys.map { $0.rect.width }), mostCommon(keys.map { $0.rect.height }))
  }

  private func mm(_ points: CGFloat) -> Float {
    Float(points / pointsPerMillimeter)
  }

  /// Natural log of the key's Gaussian density at the point.
  func score(_ key: Key, _ point: CGPoint) -> Float {
    let w = mm(key.rect.width)
    let h = mm(key.rect.height)
    let varX = 0.0075 * (1.5 * w) * (1.5 * w) + 1.68
    let varY = max(0.0108 * (1.5 * h) * (1.5 * h) + 1.33, varX * (h / w) * (h / w))
    let dx = mm(point.x - key.rect.midX)
    let dy = mm(point.y - key.rect.midY)
    let norm = Float(log(1.0 / (2.0 * Double.pi * Double(varX * varY).squareRoot())))
    return norm - 0.5 * (dx * dx / varX + dy * dy / varY)
  }

  /// [touched] first, then neighbors whose rectangle is within [radius] of the touch
  /// point and whose center is within 1.2 × [radius] of the touched key, by score.
  func alternatives(_ touched: Character, _ point: CGPoint) -> KeyAlternatives? {
    guard let touchedKey = keys.first(where: { $0.char == touched }) else { return nil }
    let neighbors =
      keys
      .filter { $0.char != touched }
      .filter {
        touchedKey.distance(to: CGPoint(x: $0.rect.midX, y: $0.rect.midY))
          <= Self.neighborFactor * radius
      }
      .filter { $0.distance(to: point) <= radius }
      .map { ($0.char, score($0, point)) }
      .sorted { $0.1 > $1.1 }
    let all = [(touched, score(touchedKey, point))] + neighbors
    return KeyAlternatives(keys: all.map { $0.0 }, scores: all.map { $0.1 })
  }
}
