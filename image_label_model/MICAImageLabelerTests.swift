//
//  MICAImageLabelerTests.swift
//  PRTSelectPhotoTests
//
//  Regression tests for the native Core ML image labeler that replaced ML Kit.
//  These cover the pieces that must stay identical to the ML Kit labeler and can
//  run without the (ODR-delivered) Core ML model: the bundled labels/calibration,
//  the per-class score calibration math, the deterministic top-N ordering, and
//  the NHWC preprocessing channel layout.
//

import UIKit
import XCTest
@testable import PRTSelectPhoto

@available(iOS 16.0, *)
final class MICAImageLabelerTests: XCTestCase {

    // MARK: - Bundled labels + calibration

    func testLabelsResourceLoadsWith447Entries() throws {
        let loaded = try XCTUnwrap(
            MICAImageLabeler.loadLabels(),
            "mica_labels_calibration.json should be bundled in the SDK resources"
        )
        XCTAssertEqual(loaded.labels.count, 447)
        XCTAssertEqual(loaded.calibrations.count, 447)
        // 17 classes have no calibration and fall back to the raw score.
        XCTAssertEqual(loaded.calibrations.filter { $0 == nil }.count, 17)
        // Index 0 is the well-known first label of the base model vocabulary.
        XCTAssertEqual(loaded.labels.first, "Team")
    }

    // MARK: - Score calibration

    func testCalibratedScoreReturnsRawWhenNoCalibration() {
        XCTAssertEqual(MICAImageLabeler.calibratedScore(raw: 0.42, calibration: nil), 0.42, accuracy: 1e-6)
    }

    func testCalibratedScoreAppliesSigmoid() {
        // calibrated = scale / (1 + exp(-(slope * raw + offset)))
        let calibration = MICAImageLabeler.Calibration(scale: 1.0, slope: 1.0, offset: 0.0)
        // raw = 0 -> 1 / (1 + exp(0)) = 0.5
        XCTAssertEqual(
            MICAImageLabeler.calibratedScore(raw: 0.0, calibration: calibration),
            0.5,
            accuracy: 1e-5
        )
        // scale scales the sigmoid output.
        let scaled = MICAImageLabeler.Calibration(scale: 0.8, slope: 2.0, offset: 1.0)
        let expected: Float = 0.8 / (1 + exp(-(2.0 * 0.3 + 1.0)))
        XCTAssertEqual(
            MICAImageLabeler.calibratedScore(raw: 0.3, calibration: scaled),
            expected,
            accuracy: 1e-5
        )
    }

    // MARK: - Top-N ordering

    func testTopLabelsSortsByConfidenceThenIndex() {
        let labels = ["a", "b", "c", "d"]
        // No calibration -> calibrated score == raw logit.
        let calibrations: [MICAImageLabeler.Calibration?] = [nil, nil, nil, nil]
        let logits: [Float] = [0.1, 0.9, 0.9, 0.5]

        let result = MICAImageLabeler.topLabels(
            logits: logits,
            labels: labels,
            calibrations: calibrations,
            maxResults: 3
        )

        XCTAssertEqual(result.count, 3)
        // Tie at 0.9 broken by ascending index -> "b" (1) before "c" (2).
        XCTAssertEqual(result[0].label, "b")
        XCTAssertEqual(result[1].label, "c")
        XCTAssertEqual(result[2].label, "d")
        XCTAssertEqual(result[0].confidence, 0.9, accuracy: 1e-6)
    }

    func testTopLabelsRespectsMaxResults() {
        let labels = (0..<100).map { "label_\($0)" }
        let calibrations = [MICAImageLabeler.Calibration?](repeating: nil, count: 100)
        let logits = (0..<100).map { Float($0) }

        let result = MICAImageLabeler.topLabels(
            logits: logits,
            labels: labels,
            calibrations: calibrations,
            maxResults: MICAImageLabeler.maxResults
        )

        XCTAssertEqual(result.count, MICAImageLabeler.maxResults)
        // Highest logit is index 99.
        XCTAssertEqual(result.first?.label, "label_99")
    }

    // MARK: - Preprocessing (NHWC channel layout)

    func testPreprocessingProducesExpectedShapeAndChannelOrder() throws {
        let image = Self.solidColorImage(.red, size: CGSize(width: 320, height: 200))
        let array = try XCTUnwrap(MICAImageLabeler.makeInputMultiArray(from: image))

        XCTAssertEqual(array.shape, [1, 224, 224, 3])
        // First pixel, NHWC: [R, G, B] at linear indices 0,1,2. Red image => high R, low G/B.
        XCTAssertGreaterThan(array[0].floatValue, 250)
        XCTAssertLessThan(array[1].floatValue, 5)
        XCTAssertLessThan(array[2].floatValue, 5)
        // Values are raw pixels in 0..255 (the model normalizes internally).
        for i in 0..<9 {
            XCTAssertGreaterThanOrEqual(array[i].floatValue, 0)
            XCTAssertLessThanOrEqual(array[i].floatValue, 255)
        }
    }

    private static func solidColorImage(_ color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
