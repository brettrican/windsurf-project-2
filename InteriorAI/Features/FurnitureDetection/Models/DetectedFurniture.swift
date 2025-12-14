//
//  DetectedFurniture.swift
//  InteriorAI
//
//  Data model for detected furniture objects
//

import Foundation
import Vision
import CoreGraphics

/// Represents the category/type of furniture
public enum FurnitureCategory: String, Codable, CaseIterable {
    case chair = "Chair"
    case table = "Table"
    case sofa = "Sofa"
    case bed = "Bed"
    case cabinet = "Cabinet"
    case bookshelf = "Bookshelf"
    case desk = "Desk"
    case lamp = "Lamp"
    case storage = "Storage"
    case decorative = "Decorative"
    case unknown = "Unknown"

    /// Display name for UI
    public var displayName: String {
        return rawValue
    }

    /// Icon name for UI representation
    public var iconName: String {
        switch self {
        case .chair: return "chair.lounge"
        case .table: return "table.furniture"
        case .sofa: return "sofa"
        case .bed: return "bed.double"
        case .cabinet: return "cabinet"
        case .bookshelf: return "books.vertical"
        case .desk: return "desk"
        case .lamp: return "lightbulb"
        case .storage: return "archivebox"
        case .decorative: return "star"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Estimated dimensions in meters (width, height, depth)
    public var typicalDimensions: (width: Float, height: Float, depth: Float) {
        switch self {
        case .chair:
            return (0.5, 0.9, 0.6)
        case .table:
            return (1.2, 0.75, 0.8)
        case .sofa:
            return (2.0, 0.8, 0.9)
        case .bed:
            return (1.6, 0.5, 2.0)
        case .cabinet:
            return (0.8, 1.8, 0.4)
        case .bookshelf:
            return (0.8, 2.0, 0.3)
        case .desk:
            return (1.5, 0.75, 0.8)
        case .lamp:
            return (0.3, 1.5, 0.3)
        case .storage:
            return (1.0, 0.8, 0.6)
        case .decorative:
            return (0.5, 0.8, 0.5)
        case .unknown:
            return (0.5, 0.5, 0.5)
        }
    }
}

/// Style classification for furniture
public enum FurnitureStyle: String, Codable, CaseIterable {
    case modern = "Modern"
    case traditional = "Traditional"
    case contemporary = "Contemporary"
    case minimalist = "Minimalist"
    case rustic = "Rustic"
    case industrial = "Industrial"
    case scandinavian = "Scandinavian"
    case midCentury = "Mid-Century Modern"
    case bohemian = "Bohemian"
    case coastal = "Coastal"
    case unknown = "Unknown"

    public var displayName: String {
        return rawValue
    }
}

/// Material classification for furniture
public enum FurnitureMaterial: String, Codable, CaseIterable {
    case wood = "Wood"
    case metal = "Metal"
    case fabric = "Fabric"
    case leather = "Leather"
    case glass = "Glass"
    case plastic = "Plastic"
    case stone = "Stone"
    case composite = "Composite"
    case mixed = "Mixed"
    case unknown = "Unknown"

    public var displayName: String {
        return rawValue
    }
}

/// Color classification for furniture
public enum FurnitureColor: String, Codable, CaseIterable {
    case white = "White"
    case black = "Black"
    case gray = "Gray"
    case brown = "Brown"
    case beige = "Beige"
    case blue = "Blue"
    case green = "Green"
    case red = "Red"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case multicolored = "Multicolored"
    case unknown = "Unknown"

    public var displayName: String {
        return rawValue
    }
}

/// Represents a bounding box for detected objects
public struct DetectionBoundingBox: Codable, Equatable {
    /// Normalized coordinates (0.0 to 1.0)
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat

    /// Original image size this bounding box relates to
    public let imageSize: CGSize

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, imageSize: CGSize) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.imageSize = imageSize
    }

    /// Creates a bounding box from a VNRectangleObservation
    public init(observation: VNRectangleObservation, imageSize: CGSize) {
        self.x = observation.boundingBox.origin.x
        self.y = observation.boundingBox.origin.y
        self.width = observation.boundingBox.width
        self.height = observation.boundingBox.height
        self.imageSize = imageSize
    }

    /// Converts to absolute pixel coordinates
    public var pixelRect: CGRect {
        return CGRect(
            x: x * imageSize.width,
            y: y * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }

    /// Center point of the bounding box
    public var center: CGPoint {
        return CGPoint(
            x: x + width / 2,
            y: y + height / 2
        )
    }

    /// Area of the bounding box (normalized)
    public var area: CGFloat {
        return width * height
    }
}

/// Represents a single detected furniture item
public struct DetectedFurniture: Codable, Identifiable, Equatable {
    /// Unique identifier for the detection
    public let id: UUID

    /// Category of furniture detected
    public let category: FurnitureCategory

    /// Confidence score (0.0 to 1.0)
    public let confidence: Float

    /// Bounding box of the detection
    public let boundingBox: DetectionBoundingBox

    /// Timestamp when detection occurred
    public let timestamp: Date

    /// Style classification if available
    public let style: FurnitureStyle?

    /// Material classification if available
    public let material: FurnitureMaterial?

    /// Color classification if available
    public let color: FurnitureColor?

    /// Additional metadata
    public let metadata: [String: String]

    public init(id: UUID = UUID(),
                category: FurnitureCategory,
                confidence: Float,
                boundingBox: DetectionBoundingBox,
                timestamp: Date = Date(),
                style: FurnitureStyle? = nil,
                material: FurnitureMaterial? = nil,
                color: FurnitureColor? = nil,
                metadata: [String: String] = [:]) {
        self.id = id
        self.category = category
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.timestamp = timestamp
        self.style = style
        self.material = material
        self.color = color
        self.metadata = metadata
    }

    /// Creates a DetectedFurniture from VNClassificationObservation
    public init?(observation: VNClassificationObservation,
                 boundingBox: DetectionBoundingBox,
                 timestamp: Date = Date()) {
        guard let category = FurnitureCategory(rawValue: observation.identifier) else {
            return nil
        }

        self.init(
            category: category,
            confidence: observation.confidence,
            boundingBox: boundingBox,
            timestamp: timestamp
        )
    }

    // MARK: - Computed Properties
    public var displayName: String {
        return category.displayName
    }

    public var iconName: String {
        return category.iconName
    }

    public var qualityScore: Float {
        // Quality based on confidence and bounding box size
        let confidenceScore = confidence
        let sizeScore = Float(min(boundingBox.area * 10, 1.0)) // Prefer larger detections
        return (confidenceScore + sizeScore) / 2.0
    }

    public var estimatedDimensions: (width: Float, height: Float, depth: Float) {
        return category.typicalDimensions
    }

    // MARK: - Validation
    public func isValid(threshold: Float = 0.5) -> Bool {
        return confidence >= threshold && boundingBox.area > 0.01 // Minimum 1% of image
    }
}

/// Represents a collection of detected furniture in a single scan/image
public struct FurnitureDetectionResult: Codable, Equatable {
    /// Unique identifier for this detection result
    public let id: UUID

    /// Array of detected furniture items
    public let detections: [DetectedFurniture]

    /// Original image size
    public let imageSize: CGSize

    /// Processing duration
    public let processingTime: TimeInterval

    /// Timestamp when detection was performed
    public let timestamp: Date

    /// Model version used for detection
    public let modelVersion: String

    public init(id: UUID = UUID(),
                detections: [DetectedFurniture],
                imageSize: CGSize,
                processingTime: TimeInterval,
                timestamp: Date = Date(),
                modelVersion: String) {
        self.id = id
        self.detections = detections
        self.imageSize = imageSize
        self.processingTime = processingTime
        self.timestamp = timestamp
        self.modelVersion = modelVersion
    }

    // MARK: - Computed Properties
    public var detectionCount: Int {
        return detections.count
    }

    public var validDetections: [DetectedFurniture] {
        return detections.filter { $0.isValid() }
    }

    public var categories: Set<FurnitureCategory> {
        return Set(detections.map { $0.category })
    }

    public var averageConfidence: Float {
        guard !detections.isEmpty else { return 0.0 }
        return detections.reduce(0) { $0 + $1.confidence } / Float(detections.count)
    }

    public var qualityScore: Float {
        let validDetectionRatio = Float(validDetections.count) / Float(max(detections.count, 1))
        let avgConfidence = averageConfidence
        return (validDetectionRatio + avgConfidence) / 2.0
    }

    // MARK: - Filtering Methods
    public func filtered(minConfidence: Float) -> FurnitureDetectionResult {
        let filteredDetections = detections.filter { $0.confidence >= minConfidence }
        return FurnitureDetectionResult(
            id: id,
            detections: filteredDetections,
            imageSize: imageSize,
            processingTime: processingTime,
            timestamp: timestamp,
            modelVersion: modelVersion
        )
    }

    public func filtered(categories: Set<FurnitureCategory>) -> FurnitureDetectionResult {
        let filteredDetections = detections.filter { categories.contains($0.category) }
        return FurnitureDetectionResult(
            id: id,
            detections: filteredDetections,
            imageSize: imageSize,
            processingTime: processingTime,
            timestamp: timestamp,
            modelVersion: modelVersion
        )
    }

    // MARK: - Statistics
    public func categoryDistribution() -> [FurnitureCategory: Int] {
        var distribution: [FurnitureCategory: Int] = [:]
        for detection in detections {
            distribution[detection.category, default: 0] += 1
        }
        return distribution
    }

    public func confidenceDistribution(bins: Int = 10) -> [Int] {
        var distribution = Array(repeating: 0, count: bins)
        let binSize = 1.0 / Float(bins)

        for detection in detections {
            let bin = min(Int(detection.confidence / binSize), bins - 1)
            distribution[bin] += 1
        }

        return distribution
    }
}

/// Represents furniture placement context within a room
public struct FurniturePlacementContext: Codable, Equatable {
    /// Detected furniture item
    public let furniture: DetectedFurniture

    /// Position in 3D space (from LiDAR scan)
    public let position: SIMD3<Float>

    /// Orientation/rotation in 3D space
    public let orientation: SIMD3<Float>

    /// Room area where furniture is placed
    public let roomArea: String?

    /// Distance to walls and other furniture
    public let spatialRelationships: [String: Float]

    public init(furniture: DetectedFurniture,
                position: SIMD3<Float>,
                orientation: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                roomArea: String? = nil,
                spatialRelationships: [String: Float] = [:]) {
        self.furniture = furniture
        self.position = position
        self.orientation = orientation
        self.roomArea = roomArea
        self.spatialRelationships = spatialRelationships
    }
}
