//
//  MICAImageLabeler.swift
//  Wrenda
//
//  Native Core ML replacement for ML Kit's base image labeler.
//
//  Backed by `MobileICA.mlpackage`, converted from ML Kit's base model
//  `mobile_ica_8bit_with_metadata.tflite`. Running the model natively lets the
//  app drop the entire ML Kit dependency chain (including the ~44 MB
//  `MLKitVisionKit` framework that both the base and custom labelers hard-link).
//
//  Model I/O (see Convert-MICA-to-CoreML-Tutorial.md):
//   - Input  `image_nhwc`  MLMultiArray [1, 224, 224, 3] float32, raw pixels 0..255.
//              The model bakes `(x - 128) / 128` normalization internally.
//   - Output single MLMultiArray of 447 logits, mapped 1:1 (0-based) to the labels.
//  ML Kit applies a per-class sigmoid score calibration on top of the raw logits;
//  we replicate it here so the calibrated confidences match the ML Kit labeler.
//

import UIKit
import CoreML
import PRTBaseLog

@available(iOS 16.0, *)
final class MICAImageLabeler {

    /// Per-class score calibration: `calibrated = scale / (1 + exp(-(slope * raw + offset)))`.
    struct Calibration: Decodable {
        let scale: Float
        let slope: Float
        let offset: Float
    }

    private struct LabelEntry: Decodable {
        let index: Int
        let name: String
        let calib: Calibration?
    }

    private struct LabelDocument: Decodable {
        let numOutputs: Int
        let labels: [LabelEntry]
    }

    /// Fixed spatial size of the model's input tensor.
    static let modelInputSize = 224
    /// The model's input feature name.
    static let inputFeatureName = "image_nhwc"
    /// Number of top labels to return, matching the previous ML Kit `prefix(40)`.
    static let maxResults = 40
    /// Resource file (bundled in the SDK) holding the 447 labels + calibration.
    private static let labelsResourceName = "mica_labels_calibration"

    private let model: MLModel
    private let labels: [String]
    private let calibrations: [Calibration?]

    private init(model: MLModel, labels: [String], calibrations: [Calibration?]) {
        self.model = model
        self.labels = labels
        self.calibrations = calibrations
    }

    // MARK: - Construction

    /// Builds a labeler from a Core ML model at `modelPath` (either a compiled
    /// `.mlmodelc` directory or an uncompiled `.mlpackage`). Returns `nil` when the
    /// model file is missing or fails to load so callers can degrade gracefully.
    static func make(modelPath: String) -> MICAImageLabeler? {
        guard let (labels, calibrations) = loadLabels() else {
            return nil
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            PRTLogger.warning(message: "[BestPhoto] MICA Core ML model missing at \(modelURL.path)")
            return nil
        }

        do {
            let compiledURL: URL
            if modelURL.pathExtension == "mlmodelc" {
                compiledURL = modelURL
            } else {
                compiledURL = try MLModel.compileModel(at: modelURL)
            }
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
            return MICAImageLabeler(model: model, labels: labels, calibrations: calibrations)
        } catch {
            PRTLogger.error(message: "[BestPhoto] Failed to load MICA Core ML model: \(error)")
            return nil
        }
    }

    /// Loads the labels + per-class calibration bundled with the SDK.
    static func loadLabels() -> (labels: [String], calibrations: [Calibration?])? {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif
        guard let url = bundle.url(forResource: labelsResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(LabelDocument.self, from: data) else {
            PRTLogger.error(message: "[BestPhoto] Failed to load \(labelsResourceName).json")
            return nil
        }

        // Order strictly by model output index so index i -> labels[i].
        let ordered = document.labels.sorted { $0.index < $1.index }
        return (ordered.map { $0.name }, ordered.map { $0.calib })
    }

    // MARK: - Inference

    /// Runs the labeler on a normalized image. Returns calibrated top-N labels,
    /// or `[]` on any failure.
    func label(image: UIImage) -> [PRTImageLabel] {
        guard let input = Self.makeInputMultiArray(from: image) else {
            return []
        }

        do {
            let provider = try MLDictionaryFeatureProvider(
                dictionary: [Self.inputFeatureName: MLFeatureValue(multiArray: input)]
            )
            let output = try model.prediction(from: provider)
            // The converted model exposes a single output feature (the logits).
            guard let featureName = output.featureNames.first,
                  let logitsArray = output.featureValue(for: featureName)?.multiArrayValue else {
                return []
            }

            var logits = [Float](repeating: 0, count: logitsArray.count)
            for i in 0..<logitsArray.count {
                logits[i] = logitsArray[i].floatValue
            }

            return Self.topLabels(
                logits: logits,
                labels: labels,
                calibrations: calibrations,
                maxResults: Self.maxResults
            )
        } catch {
            PRTLogger.error(message: "[BestPhoto] MICA Core ML prediction failed: \(error)")
            return []
        }
    }

    // MARK: - Preprocessing

    /// Converts a UIImage into the model's `[1, 224, 224, 3]` float32 NHWC input,
    /// raw RGB pixels `0..255` (the model normalizes internally). The image is
    /// resized (stretched) to exactly 224×224, matching how ML Kit resizes the
    /// input to the model's fixed tensor dimensions.
    static func makeInputMultiArray(from image: UIImage) -> MLMultiArray? {
        let side = modelInputSize
        guard let cgImage = image.cgImage else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // RGBX (skip alpha, no premultiplication) so pixel bytes are untouched RGB.
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        guard let context = buffer.withUnsafeMutableBytes({ raw -> CGContext? in
            CGContext(
                data: raw.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        guard let array = try? MLMultiArray(
            shape: [1, NSNumber(value: side), NSNumber(value: side), 3],
            dataType: .float32
        ) else {
            return nil
        }

        // NHWC contiguous: element (0, y, x, c) = ((y * side) + x) * 3 + c.
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
        var destination = 0
        var source = 0
        let total = buffer.count
        while source < total {
            pointer[destination] = Float(buffer[source])       // R
            pointer[destination + 1] = Float(buffer[source + 1]) // G
            pointer[destination + 2] = Float(buffer[source + 2]) // B
            destination += 3
            source += bytesPerPixel
        }
        return array
    }

    // MARK: - Post-processing (pure, unit-testable)

    /// Applies ML Kit's per-class score calibration to a raw logit.
    static func calibratedScore(raw: Float, calibration: Calibration?) -> Float {
        guard let calibration else {
            return raw
        }
        return calibration.scale / (1 + exp(-(calibration.slope * raw + calibration.offset)))
    }

    /// Maps raw logits to calibrated, sorted top-N labels. Sorted by descending
    /// confidence, tie-broken by ascending class index for deterministic output —
    /// matching the previous ML Kit ordering.
    static func topLabels(
        logits: [Float],
        labels: [String],
        calibrations: [Calibration?],
        maxResults: Int
    ) -> [PRTImageLabel] {
        let count = min(logits.count, labels.count, calibrations.count)
        guard count > 0 else {
            return []
        }

        var scored: [(index: Int, score: Float)] = []
        scored.reserveCapacity(count)
        for i in 0..<count {
            scored.append((i, calibratedScore(raw: logits[i], calibration: calibrations[i])))
        }

        scored.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.index < rhs.index
            }
            return lhs.score > rhs.score
        }

        return scored.prefix(maxResults).map { (label: labels[$0.index], confidence: $0.score) }
    }
}
