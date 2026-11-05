//
//  PhotoScoreService.swift
//  UIQACoreMLDemo
//
//  Created by Gavin Xiang on 10/16/26.
//  Copyright © 2026 PlanetArt. All rights reserved.
//

import CoreML
import CoreVideo
import OSLog
import UIKit

private let log = Logger(subsystem: "com.planetart.UIQACoreMLDemo", category: "PhotoScore")

struct PhotoScore {
    var value: Float
    var elapsed: Duration
}

protocol PhotoScoring {
    func loadModel() async throws -> Duration
    func score(_ image: UIImage) async throws -> PhotoScore
}

enum PhotoScoreError: LocalizedError {
    case modelMissing
    case outputMissing
    case imageUnreadable
    case predictionFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            String(localized: "The quality model is not in the app.")
        case .outputMissing:
            String(localized: "The quality model did not return a score.")
        case .imageUnreadable:
            String(localized: "Could not read that photo.")
        case .predictionFailed:
            String(localized: "Core ML could not score that photo.")
        }
    }
}

/// Loads the compiled ReGLA-m package and scores one center-cropped photo.
final class PhotoScoreService: PhotoScoring {
    private var model: MLModel?

    func loadModel() async throws -> Duration {
        if model != nil {
            return .zero
        }
        let url = try modelURL()
        log.debug("Loading Core ML model")
        let started = ContinuousClock.now
        let loaded = try await Self.makeModel(at: url)
        model = loaded
        return started.duration(to: .now)
    }

    func score(_ image: UIImage) async throws -> PhotoScore {
        if model == nil {
            _ = try await loadModel()
        }
        guard let model else { throw PhotoScoreError.modelMissing }
        let buffer = try PhotoTensor.pixelBuffer(from: image, side: PhotoTensor.inputSize)
        let started = ContinuousClock.now
        let output = try await Self.predict(model: model, buffer: buffer)
        guard let score = output.featureValue(for: "quality_score")?.multiArrayValue?[0].floatValue else {
            throw PhotoScoreError.outputMissing
        }
        return PhotoScore(value: score, elapsed: started.duration(to: .now))
    }

    private func modelURL() throws -> URL {
        if let compiled = Bundle.main.url(forResource: "UIQAModel_ReGLA_m", withExtension: "mlmodelc") {
            return compiled
        }
        if let package = Bundle.main.url(forResource: "UIQAModel_ReGLA_m", withExtension: "mlpackage") {
            return package
        }
        log.error("UIQAModel_ReGLA_m.mlmodelc is missing from the app bundle")
        throw PhotoScoreError.modelMissing
    }

    private static func makeModel(at url: URL) async throws -> MLModel {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let configuration = MLModelConfiguration()
                configuration.computeUnits = .all
                do {
                    let model = try MLModel(contentsOf: url, configuration: configuration)
                    continuation.resume(returning: model)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func predict(model: MLModel, buffer: CVPixelBuffer) async throws -> MLFeatureProvider {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let input = try MLDictionaryFeatureProvider(dictionary: [
                        "input_aesthetics": MLFeatureValue(pixelBuffer: buffer),
                        "input_distortion": MLFeatureValue(pixelBuffer: buffer),
                        "input_saliency": MLFeatureValue(pixelBuffer: buffer),
                    ])
                    continuation.resume(returning: try model.prediction(from: input))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private enum PhotoTensor {
    static let inputSize = 480

    static func pixelBuffer(from image: UIImage, side: Int) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            side,
            side,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw PhotoScoreError.imageUnreadable
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw PhotoScoreError.imageUnreadable
        }
        context.interpolationQuality = .high
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        guard pixelWidth > 0, pixelHeight > 0 else { throw PhotoScoreError.imageUnreadable }
        let crop = min(pixelWidth, pixelHeight)
        let scale = CGFloat(side) / crop
        let drawRect = CGRect(
            x: -((pixelWidth - crop) / 2) * scale,
            y: -((pixelHeight - crop) / 2) * scale,
            width: pixelWidth * scale,
            height: pixelHeight * scale
        )
        UIGraphicsPushContext(context)
        image.draw(in: drawRect)
        UIGraphicsPopContext()
        return buffer
    }
}
