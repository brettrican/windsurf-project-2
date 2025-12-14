//
//  FurnitureDetectionService.swift
//  InteriorAI
//
//  Service for furniture detection using Core ML and Vision frameworks
//

import Foundation
import Vision
import CoreML
import UIKit
import Combine

/// Detection state
public enum DetectionState {
    case idle
    case preparing
    case detecting
    case processing
    case completed
    case failed(DetectionError)
}

/// Detection configuration
public struct DetectionConfiguration {
    public let confidenceThreshold: Float
    public let maxResults: Int
    public let enableClassification: Bool
    public let enableStyleAnalysis: Bool

    public init(confidenceThreshold: Float = MLConstants.confidenceThreshold,
                maxResults: Int = 10,
                enableClassification: Bool = true,
                enableStyleAnalysis: Bool = true) {
        self.confidenceThreshold = confidenceThreshold
        self.maxResults = maxResults
        self.enableClassification = enableClassification
        self.enableStyleAnalysis = enableStyleAnalysis
    }
}

/// Detection progress information
public struct DetectionProgress {
    public let state: DetectionState
    public let progress: Float // 0.0 to 1.0
    public let currentItem: Int
    public let totalItems: Int
    public let currentItemName: String?

    public init(state: DetectionState,
                progress: Float = 0.0,
                currentItem: Int = 0,
                totalItems: Int = 0,
                currentItemName: String? = nil) {
        self.state = state
        self.progress = progress
        self.currentItem = currentItem
        self.totalItems = totalItems
        self.currentItemName = currentItemName
    }
}

/// Furniture detection service with Core ML integration
public final class FurnitureDetectionService {
    // MARK: - Singleton
    public static let shared = FurnitureDetectionService()

    // MARK: - Properties
    private let processingQueue = DispatchQueue(label: "com.interiorai.detection.processing", qos: .userInitiated)
    private let modelQueue = DispatchQueue(label: "com.interiorai.detection.model", qos: .userInitiated)

    // ML Models
    private var detectionModel: VNCoreMLModel?
    private var classificationModel: VNCoreMLModel?
    private var styleAnalysisModel: VNCoreMLModel?

    // Publishers
    public let detectionProgress = PassthroughSubject<DetectionProgress, Never>()
    public let detectionCompleted = PassthroughSubject<Result<FurnitureDetectionResult, DetectionError>, Never>()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        setupModels()
    }

    // MARK: - Public Interface

    /// Detects furniture in the provided image
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - configuration: Detection configuration
    /// - Returns: Publisher that emits detection results
    public func detectFurniture(in image: UIImage,
                               configuration: DetectionConfiguration = DetectionConfiguration()) -> AnyPublisher<FurnitureDetectionResult, DetectionError> {
        Logger.shared.detection("Starting furniture detection for image \(image.size)")

        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.detectionFailed("Service unavailable")))
                return
            }

            self.processingQueue.async {
                self.performDetection(image: image, configuration: configuration) { result in
                    switch result {
                    case .success(let detectionResult):
                        Logger.shared.detection("Detection completed successfully with \(detectionResult.detections.count) items")
                        promise(.success(detectionResult))
                    case .failure(let error):
                        Logger.shared.error("Detection failed", error: error, category: .detection)
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Detects furniture in multiple images
    /// - Parameters:
    ///   - images: Array of images to analyze
    ///   - configuration: Detection configuration
    /// - Returns: Publisher that emits progress and final results
    public func detectFurnitureInBatch(images: [UIImage],
                                      configuration: DetectionConfiguration = DetectionConfiguration()) -> AnyPublisher<FurnitureDetectionResult, DetectionError> {
        Logger.shared.detection("Starting batch detection for \(images.count) images")

        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.detectionFailed("Service unavailable")))
                return
            }

            self.processingQueue.async {
                self.performBatchDetection(images: images, configuration: configuration) { result in
                    switch result {
                    case .success(let detectionResult):
                        Logger.shared.detection("Batch detection completed successfully with \(detectionResult.detections.count) total detections")
                        promise(.success(detectionResult))
                    case .failure(let error):
                        Logger.shared.error("Batch detection failed", error: error, category: .detection)
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Checks if detection models are available and loaded
    public func areModelsAvailable() -> Bool {
        return detectionModel != nil
    }

    /// Gets the names of available models
    public func getAvailableModels() -> [String] {
        var models = [String]()
        if detectionModel != nil { models.append("FurnitureDetection") }
        if classificationModel != nil { models.append("FurnitureClassification") }
        if styleAnalysisModel != nil { models.append("StyleAnalysis") }
        return models
    }

    // MARK: - Private Implementation

    private func setupModels() {
        Logger.shared.detection("Setting up Core ML models")

        // Load detection model
        loadModel(named: MLConstants.furnitureDetectionModel) { [weak self] result in
            switch result {
            case .success(let model):
                self?.detectionModel = model
                Logger.shared.detection("Detection model loaded successfully")
            case .failure(let error):
                Logger.shared.error("Failed to load detection model", error: error, category: .detection)
            }
        }

        // Load classification model
        loadModel(named: MLConstants.designRecommendationModel) { [weak self] result in
            switch result {
            case .success(let model):
                self?.classificationModel = model
                Logger.shared.detection("Classification model loaded successfully")
            case .failure(let error):
                Logger.shared.error("Failed to load classification model", error: error, category: .detection)
            }
        }
    }

    private func loadModel(named modelName: String, completion: @escaping (Result<VNCoreMLModel, DetectionError>) -> Void) {
        modelQueue.async {
            do {
                // Try to load model from bundle
                guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
                    // Model not in bundle, try to download or use default
                    Logger.shared.warning("Model \(modelName) not found in bundle, using fallback", category: .detection)
                    completion(.failure(.modelNotFound(modelName)))
                    return
                }

                let compiledModelURL = try MLModel.compileModel(at: modelURL)
                let mlModel = try MLModel(contentsOf: compiledModelURL)
                let vnModel = try VNCoreMLModel(for: mlModel)

                completion(.success(vnModel))

            } catch {
                completion(.failure(.modelLoadingFailed(error.localizedDescription)))
            }
        }
    }

    private func performDetection(image: UIImage,
                                configuration: DetectionConfiguration,
                                completion: @escaping (Result<FurnitureDetectionResult, DetectionError>) -> Void) {

        let startTime = Date()

        // Validate image
        guard let cgImage = image.cgImage else {
            completion(.failure(.invalidImageData))
            return
        }

        // Check image size
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let minSize = CGSize(width: 224, height: 224) // Typical ML model input size
        let maxSize = CGSize(width: 4096, height: 4096) // Reasonable maximum

        if imageSize.width < minSize.width || imageSize.height < minSize.height {
            completion(.failure(.imageTooSmall(imageSize, minSize)))
            return
        }

        if imageSize.width > maxSize.width || imageSize.height > maxSize.height {
            completion(.failure(.imageTooLarge(imageSize, maxSize)))
            return
        }

        // Create detection request
        guard let detectionModel = detectionModel else {
            completion(.failure(.modelNotFound(MLConstants.furnitureDetectionModel)))
            return
        }

        let detectionRequest = VNCoreMLRequest(model: detectionModel) { [weak self] request, error in
            if let error = error {
                completion(.failure(.detectionFailed(error.localizedDescription)))
                return
            }

            self?.processDetectionResults(request: request,
                                        imageSize: imageSize,
                                        configuration: configuration,
                                        startTime: startTime,
                                        completion: completion)
        }

        detectionRequest.imageCropAndScaleOption = .scaleFit

        // Perform detection
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([detectionRequest])
        } catch {
            completion(.failure(.imageProcessingFailed(error.localizedDescription)))
        }
    }

    private func performBatchDetection(images: [UIImage],
                                     configuration: DetectionConfiguration,
                                     completion: @escaping (Result<FurnitureDetectionResult, DetectionError>) -> Void) {

        let startTime = Date()
        var allDetections = [DetectedFurniture]()
        let totalImages = images.count

        // Update progress
        detectionProgress.send(DetectionProgress(state: .preparing, progress: 0.0, currentItem: 0, totalItems: totalImages))

        let dispatchGroup = DispatchGroup()

        for (index, image) in images.enumerated() {
            dispatchGroup.enter()

            detectionProgress.send(DetectionProgress(
                state: .detecting,
                progress: Float(index) / Float(totalImages),
                currentItem: index + 1,
                totalItems: totalImages,
                currentItemName: "Image \(index + 1)"
            ))

            performDetection(image: image, configuration: configuration) { result in
                switch result {
                case .success(let detectionResult):
                    // Merge detections from this image
                    allDetections.append(contentsOf: detectionResult.detections)
                case .failure(let error):
                    Logger.shared.warning("Detection failed for image \(index + 1): \(error.localizedDescription)", category: .detection)
                    // Continue with other images
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: processingQueue) { [weak self] in
            self?.finalizeBatchDetection(
                detections: allDetections,
                imageCount: totalImages,
                startTime: startTime,
                completion: completion
            )
        }
    }

    private func processDetectionResults(request: VNRequest,
                                       imageSize: CGSize,
                                       configuration: DetectionConfiguration,
                                       startTime: Date,
                                       completion: @escaping (Result<FurnitureDetectionResult, DetectionError>) -> Void) {

        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            completion(.failure(.invalidDetectionResult("Invalid detection results format")))
            return
        }

        // Filter and process detections
        let validDetections = results
            .filter { $0.confidence >= configuration.confidenceThreshold }
            .prefix(configuration.maxResults)
            .compactMap { observation -> DetectedFurniture? in
                processSingleDetection(observation, imageSize: imageSize, configuration: configuration)
            }

        let processingTime = Date().timeIntervalSince(startTime)

        let detectionResult = FurnitureDetectionResult(
            detections: validDetections,
            imageSize: imageSize,
            processingTime: processingTime,
            modelVersion: "1.0.0"
        )

        completion(.success(detectionResult))
    }

    private func processSingleDetection(_ observation: VNRecognizedObjectObservation,
                                      imageSize: CGSize,
                                      configuration: DetectionConfiguration) -> DetectedFurniture? {

        guard let topLabel = observation.labels.first else { return nil }

        // Map label to furniture category
        guard let category = FurnitureCategory(rawValue: topLabel.identifier) else {
            // Try to map common labels to categories
            let mappedCategory = mapLabelToCategory(topLabel.identifier)
            guard let category = mappedCategory else { return nil }
        }

        // Create bounding box
        let boundingBox = DetectionBoundingBox(
            observation: observation,
            imageSize: imageSize
        )

        // Create detection
        let detection = DetectedFurniture(
            category: category,
            confidence: observation.confidence,
            boundingBox: boundingBox,
            metadata: [
                "originalLabel": topLabel.identifier,
                "boundingBoxArea": String(format: "%.4f", boundingBox.area)
            ]
        )

        // Perform additional classification if enabled
        if configuration.enableClassification && classificationModel != nil {
            // Additional classification would go here
            // For now, we keep the basic detection
        }

        return detection
    }

    private func mapLabelToCategory(_ label: String) -> FurnitureCategory? {
        let lowercasedLabel = label.lowercased()

        // Simple mapping for common furniture labels
        if lowercasedLabel.contains("chair") {
            return .chair
        } else if lowercasedLabel.contains("table") {
            return .table
        } else if lowercasedLabel.contains("sofa") || lowercasedLabel.contains("couch") {
            return .sofa
        } else if lowercasedLabel.contains("bed") {
            return .bed
        } else if lowercasedLabel.contains("cabinet") || lowercasedLabel.contains("wardrobe") {
            return .cabinet
        } else if lowercasedLabel.contains("bookshelf") || lowercasedLabel.contains("bookcase") {
            return .bookshelf
        } else if lowercasedLabel.contains("desk") {
            return .desk
        } else if lowercasedLabel.contains("lamp") {
            return .lamp
        }

        return .unknown
    }

    private func finalizeBatchDetection(detections: [DetectedFurniture],
                                      imageCount: Int,
                                      startTime: Date,
                                      completion: @escaping (Result<FurnitureDetectionResult, DetectionError>) -> Void) {

        let processingTime = Date().timeIntervalSince(startTime)

        // Create combined result
        let batchResult = FurnitureDetectionResult(
            detections: detections,
            imageSize: CGSize(width: 0, height: 0), // Not applicable for batch
            processingTime: processingTime,
            modelVersion: "1.0.0-batch"
        )

        // Update final progress
        detectionProgress.send(DetectionProgress(
            state: .completed,
            progress: 1.0,
            currentItem: imageCount,
            totalItems: imageCount
        ))

        completion(.success(batchResult))
    }

    // MARK: - Model Management

    /// Preloads models for faster detection
    public func preloadModels() {
        Logger.shared.detection("Preloading detection models")

        // Models are already loaded during init
        // This method could be used for additional preloading if needed
    }

    /// Unloads models to free memory
    public func unloadModels() {
        Logger.shared.detection("Unloading detection models")

        detectionModel = nil
        classificationModel = nil
        styleAnalysisModel = nil
    }
}

// MARK: - Convenience Extensions

public extension FurnitureDetectionService {
    /// Detects furniture in a photo with default settings
    func detectFurniture(in image: UIImage) -> AnyPublisher<FurnitureDetectionResult, DetectionError> {
        return detectFurniture(in: image, configuration: DetectionConfiguration())
    }

    /// Gets detection statistics for a result
    func getDetectionStatistics(for result: FurnitureDetectionResult) -> DetectionStatistics {
        let categories = Dictionary(grouping: result.detections, by: { $0.category })
            .mapValues { $0.count }

        let averageConfidence = result.detections.isEmpty ? 0 :
            result.detections.reduce(0) { $0 + $1.confidence } / Float(result.detections.count)

        return DetectionStatistics(
            totalDetections: result.detections.count,
            detectionsByCategory: categories,
            averageConfidence: averageConfidence,
            processingTime: result.processingTime
        )
    }
}

/// Detection statistics
public struct DetectionStatistics {
    public let totalDetections: Int
    public let detectionsByCategory: [FurnitureCategory: Int]
    public let averageConfidence: Float
    public let processingTime: TimeInterval
}
