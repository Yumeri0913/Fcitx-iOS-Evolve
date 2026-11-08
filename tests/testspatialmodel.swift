import CoreGraphics
import Foundation

// Ported from InsightKey's SpatialModelTest.kt.

private var failures = 0

private func expect(_ condition: Bool, _ message: String) {
  if !condition {
    print("FAILED: \(message)")
    failures += 1
  }
}

// 420 dpi phone, 108 x 160 px keys (6.53 mm x 9.68 mm), staggered QWERTY.
private let dpi: CGFloat = 420
private let w: CGFloat = 108
private let h: CGFloat = 160

private let keys: [SpatialModel.Key] = {
  var keys = [SpatialModel.Key]()
  for (row, (letters, offset)) in [("qwertyuiop", 0.0), ("asdfghjkl", 0.5), ("zxcvbnm", 1.5)]
    .enumerated()
  {
    for (i, c) in letters.enumerated() {
      let left = (CGFloat(offset) + CGFloat(i)) * w
      keys.append(
        SpatialModel.Key(char: c, rect: CGRect(x: left, y: CGFloat(row) * h, width: w, height: h)))
    }
  }
  return keys
}()
private let model = SpatialModel(keys: keys, pointsPerMillimeter: dpi / 25.4)
private func key(_ c: Character) -> SpatialModel.Key { keys.first { $0.char == c }! }

private func testScoreIsGoogleGaussian() {
  let k = key("g")
  let wMm = Float(w * 25.4 / dpi)
  let hMm = Float(h * 25.4 / dpi)
  let varX = 0.0075 * (1.5 * wMm) * (1.5 * wMm) + 1.68
  let varY = 0.0108 * (1.5 * hMm) * (1.5 * hMm) + 1.33
  let peak = Float(log(1.0 / (2 * Double.pi * Double(varX * varY).squareRoot())))
  let center = CGPoint(x: k.rect.midX, y: k.rect.midY)
  expect(abs(model.score(k, center) - peak) < 1e-4, "peak")
  let dxMm: Float = 2
  let p = CGPoint(x: k.rect.midX + CGFloat(dxMm) * dpi / 25.4, y: k.rect.midY)
  expect(abs(model.score(k, p) - (peak - 0.5 * dxMm * dxMm / varX)) < 1e-3, "2 mm off center")
}

private func testTouchAtCenterRanksTouchedKeyFarAhead() {
  let k = key("g")
  let alt = model.alternatives("g", CGPoint(x: k.rect.midX, y: k.rect.midY))!
  expect(alt.keys[0] == "g", "touched key first")
  // At the key center, neighbors are more than 1000x less likely.
  expect(alt.keys.count == 1 || alt.scores[0] - alt.scores[1] > log(1000), "center dominates")
}

private func testTouchOnBorderMakesNeighborAsLikely() {
  let g = key("g")
  let alt = model.alternatives("g", CGPoint(x: g.rect.maxX - 1, y: g.rect.midY))!
  expect(alt.keys[0] == "g" && alt.keys[1] == "h", "g then h: \(alt.keys)")
  expect(abs(alt.scores[0] - alt.scores[1]) < 0.2, "border scores close")
  let rest = Array(alt.scores.dropFirst())
  expect(zip(rest, rest.dropFirst()).allSatisfy { $0 >= $1 }, "neighbors sorted")
}

private func testVerticalNeighborsAreIncluded() {
  // Bottom edge of u is next to h and j.
  let u = key("u")
  let alt = model.alternatives("u", CGPoint(x: u.rect.midX, y: u.rect.maxY - 1))!
  expect(alt.keys.contains("j") || alt.keys.contains("h"), "vertical neighbor: \(alt.keys)")
  // Far keys are never considered.
  expect(!alt.keys.contains("m") && !alt.keys.contains("p"), "no far keys")
}

private func testUnknownKeyGivesNothing() {
  expect(model.alternatives("1", .zero) == nil, "unknown key")
}

@main
struct SpatialModelTests {
  static func main() {
    testScoreIsGoogleGaussian()
    testTouchAtCenterRanksTouchedKeyFarAhead()
    testTouchOnBorderMakesNeighborAsLikely()
    testVerticalNeighborsAreIncluded()
    testUnknownKeyGivesNothing()
    if failures > 0 {
      fatalError("\(failures) spatial model tests failed")
    }
    print("Spatial model tests passed")
  }
}
