//
//  PhotoScoreService.swift
//  UIQAScoreDemo
//
//  Created by Gavin Xiang on 10/16/26.
//  Copyright © 2026 PlanetArt. All rights reserved.
//

import OSLog
import UIKit

#if canImport(CoreAI)
import CoreAI
#endif

private let log = Logger(subsystem: "com.planetart.UIQAScoreDemo", category: "PhotoScore")

struct PhotoScore {
    var value: Float
    var elapsed: Duration
}

struct ModelLoadResult {
    var elapsed: Duration
    var detail: String
}

protocol PhotoScoring {
    func loadModel() async throws -> ModelLoadResult
    func score(_ image: UIImage) async throws -> PhotoScore
}

enum PhotoScoreError: LocalizedError {
    case modelMissing
    case functionMissing
    case outputMissing
    case imageUnreadable
    case unavailableOnSimulator

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            String(localized: "The quality model is not in the app.")
        case .functionMissing:
            String(localized: "The quality model has no main function.")
        case .outputMissing:
            String(localized: "The quality model did not return a score.")
        case .imageUnreadable:
            String(localized: "Could not read that photo.")
        case .unavailableOnSimulator:
            String(localized: "Photo scoring needs an iOS 27 device. Core AI is not in the simulator.")
        }
    }
}

/// Loads the ahead-of-time compiled UIQA model and scores one center-cropped photo.
final class PhotoScoreService: PhotoScoring {
    func loadModel() async throws -> ModelLoadResult {
        #if canImport(CoreAI)
        try await CoreAIPhotoScoreEngine.shared.loadModel()
        #else
        throw PhotoScoreError.unavailableOnSimulator
        #endif
    }

    func score(_ image: UIImage) async throws -> PhotoScore {
        #if canImport(CoreAI)
        try await CoreAIPhotoScoreEngine.shared.score(image)
        #else
        throw PhotoScoreError.unavailableOnSimulator
        #endif
    }
}

#if canImport(CoreAI)
private final class CoreAIPhotoScoreEngine {
    static let shared = CoreAIPhotoScoreEngine()
    static let inputSize = 360

    private var model: AIModel?
    private var function: InferenceFunction?
    private var loadedDetail = ""
    private var resourceRequest: NSBundleResourceRequest?

    func loadModel() async throws -> ModelLoadResult {
        if function != nil {
            return ModelLoadResult(elapsed: .zero, detail: loadedDetail)
        }
        let located = try await modelURL()
        let started = ContinuousClock.now
        let options = SpecializationOptions(preferredComputeUnitKind: .gpu)
        let cacheStarted = ContinuousClock.now
        let cached = try AIModelCache.default.model(for: located.url, options: options)
        logCost("load cache lookup", since: cacheStarted)
        if cached == nil {
            let specializeStarted = ContinuousClock.now
            _ = try await AIModel.specialize(
                contentsOf: located.url,
                options: options,
                cache: .default,
                cachePolicy: .persistent
            )
            logCost("load specialize", since: specializeStarted)
        } else {
            #if DEBUG
            log.info("load specialize: cache hit")
            #endif
        }
        let openStarted = ContinuousClock.now
        let model = try await AIModel(contentsOf: located.url, options: options)
        logCost("load AIModel", since: openStarted)
        let functionStarted = ContinuousClock.now
        guard let function = try model.loadFunction(named: "main") else {
            log.error("UIQA model is missing the main function")
            throw PhotoScoreError.functionMissing
        }
        logCost("load function", since: functionStarted)
        let warmupStarted = ContinuousClock.now
        try await warmUp(function)
        logCost("load warmup", since: warmupStarted)
        self.model = model
        self.function = function
        loadedDetail = located.detail
        logCost("load total \(located.detail)", since: started)
        return ModelLoadResult(elapsed: started.duration(to: .now), detail: located.detail)
    }

    func score(_ image: UIImage) async throws -> PhotoScore {
        if function == nil {
            _ = try await loadModel()
        }
        guard let function else { throw PhotoScoreError.modelMissing }
        let started = ContinuousClock.now
        let pixelsStarted = ContinuousClock.now
        let pixels = try PhotoTensor.rgbFloats(from: image, side: Self.inputSize)
        logCost("score pixels", since: pixelsStarted)
        let inputStarted = ContinuousClock.now
        let input = NDArray(scalars: pixels, shape: [1, 3, Self.inputSize, Self.inputSize])
        logCost("score input", since: inputStarted)
        let runStarted = ContinuousClock.now
        var outputs = try await function.run(inputs: ["image": input])
        logCost("score run", since: runStarted)
        let readStarted = ContinuousClock.now
        guard let value = outputs.remove("quality_score") else {
            throw PhotoScoreError.outputMissing
        }
        guard let array = value.ndArray else {
            throw PhotoScoreError.outputMissing
        }
        let scoreView = array.view(as: Float.self)
        guard let elements = scoreView.contiguousElements else {
            throw PhotoScoreError.outputMissing
        }
        logCost("score read", since: readStarted)
        let elapsed = started.duration(to: .now)
        logCost("score total", since: started)
        return PhotoScore(value: elements[0], elapsed: elapsed)
    }

    /// The first `run` finishes GPU pipeline setup. Do that before the user scores a photo.
    private func warmUp(_ function: InferenceFunction) async throws {
        let count = 3 * Self.inputSize * Self.inputSize
        let pixels = [Float](repeating: 0, count: count)
        let input = NDArray(scalars: pixels, shape: [1, 3, Self.inputSize, Self.inputSize])
        _ = try await function.run(inputs: ["image": input])
    }

    private func logCost(_ step: String, since start: ContinuousClock.Instant) {
        #if DEBUG
        let seconds = String(format: "%.3f", seconds(from: start))
        log.info("\(step, privacy: .public): \(seconds, privacy: .public)s")
        #endif
    }

    private func seconds(from start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now)
        return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private func modelURL() async throws -> (url: URL, detail: String) {
        let architecture = AIModel.deviceArchitectureName
        if let url = await downloadCompiledModel(architecture: architecture) {
            return (url, "odr \(architecture)")
        }
        if let url = Bundle.main.url(forResource: "UIQAModel", withExtension: "aimodel") {
            log.error("No on-demand model for \(architecture, privacy: .public); falling back to source aimodel")
            return (url, "source aimodel, device \(architecture)")
        }
        log.error("UIQAModel.aimodelc is missing for \(architecture, privacy: .public)")
        throw PhotoScoreError.modelMissing
    }

    /// Downloads only this device's compiled model. The request stays alive so the system keeps the file.
    private func downloadCompiledModel(architecture: String) async -> URL? {
        let request = NSBundleResourceRequest(tags: [architecture])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        let started = ContinuousClock.now
        do {
            try await request.beginAccessingResources()
        } catch {
            log.error("ODR download failed for \(architecture, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
        logCost("odr download", since: started)
        let name = "UIQAModel.\(architecture)"
        guard let url = Bundle.main.url(forResource: name, withExtension: "aimodelc") else {
            log.error("ODR tag \(architecture, privacy: .public) has no \(name, privacy: .public).aimodelc")
            request.endAccessingResources()
            return nil
        }
        resourceRequest = request
        return url
    }
}
#endif

private enum PhotoTensor {
    /// Center-crops to a square and returns NCHW RGB floats in 0...255.
    static func rgbFloats(from image: UIImage, side: Int) throws -> [Float] {
        let rgba = try rgbaBytes(from: image, side: side)
        let plane = side * side
        var floats = [Float](repeating: 0, count: 3 * plane)
        for index in 0..<plane {
            let source = index * 4
            floats[index] = Float(rgba[source])
            floats[plane + index] = Float(rgba[source + 1])
            floats[(2 * plane) + index] = Float(rgba[source + 2])
        }
        return floats
    }

    private static func rgbaBytes(from image: UIImage, side: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drew = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .high
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            guard pixelWidth > 0, pixelHeight > 0 else { return false }
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
            return true
        }
        guard drew else { throw PhotoScoreError.imageUnreadable }
        return bytes
    }
}
