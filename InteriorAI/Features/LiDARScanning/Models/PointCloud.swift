//
//  PointCloud.swift
//  InteriorAI
//
//  Data model for LiDAR point cloud data
//

import Foundation
import simd

/// Represents a 3D point in the point cloud with position and confidence
public struct PointCloudPoint: Codable, Equatable, Hashable {
    /// 3D position of the point
    public let position: SIMD3<Float>

    /// Confidence value (0.0 to 1.0)
    public let confidence: Float

    /// RGB color information if available
    public let color: SIMD3<UInt8>?

    public init(position: SIMD3<Float>, confidence: Float, color: SIMD3<UInt8>? = nil) {
        self.position = position
        self.confidence = confidence
        self.color = color
    }

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case position, confidence, color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(SIMD3<Float>.self, forKey: .position)
        confidence = try container.decode(Float.self, forKey: .confidence)
        color = try container.decodeIfPresent(SIMD3<UInt8>.self, forKey: .color)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(color, forKey: .color)
    }

    // MARK: - Equatable & Hashable
    public static func == (lhs: PointCloudPoint, rhs: PointCloudPoint) -> Bool {
        return lhs.position == rhs.position &&
               lhs.confidence == rhs.confidence &&
               lhs.color == rhs.color
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(confidence)
        hasher.combine(color)
    }
}

/// Represents metadata for a point cloud
public struct PointCloudMetadata: Codable, Equatable {
    /// Total number of points in the cloud
    public let pointCount: Int

    /// Bounding box of the point cloud
    public let bounds: BoundingBox

    /// Average confidence of all points
    public let averageConfidence: Float

    /// Timestamp when the scan was created
    public let timestamp: Date

    /// Device information
    public let deviceModel: String

    /// Scan duration in seconds
    public let scanDuration: TimeInterval

    /// Quality score (0.0 to 1.0)
    public let qualityScore: Float

    public init(pointCount: Int,
                bounds: BoundingBox,
                averageConfidence: Float,
                timestamp: Date = Date(),
                deviceModel: String,
                scanDuration: TimeInterval,
                qualityScore: Float) {
        self.pointCount = pointCount
        self.bounds = bounds
        self.averageConfidence = averageConfidence
        self.timestamp = timestamp
        self.deviceModel = deviceModel
        self.scanDuration = scanDuration
        self.qualityScore = qualityScore
    }
}

/// Represents the bounding box of a point cloud
public struct BoundingBox: Codable, Equatable {
    /// Minimum corner of the bounding box
    public let min: SIMD3<Float>

    /// Maximum corner of the bounding box
    public let max: SIMD3<Float>

    /// Center point of the bounding box
    public var center: SIMD3<Float> {
        return (min + max) * 0.5
    }

    /// Size/extent of the bounding box
    public var size: SIMD3<Float> {
        return max - min
    }

    /// Volume of the bounding box
    public var volume: Float {
        let size = self.size
        return size.x * size.y * size.z
    }

    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }

    /// Creates a bounding box that encompasses all points in the array
    public init?(points: [SIMD3<Float>]) {
        guard !points.isEmpty else { return nil }

        var min = points[0]
        var max = points[0]

        for point in points.dropFirst() {
            min.x = Swift.min(min.x, point.x)
            min.y = Swift.min(min.y, point.y)
            min.z = Swift.min(min.z, point.z)
            max.x = Swift.max(max.x, point.x)
            max.y = Swift.max(max.y, point.y)
            max.z = Swift.max(max.z, point.z)
        }

        self.min = min
        self.max = max
    }

    /// Checks if a point is contained within the bounding box
    public func contains(_ point: SIMD3<Float>) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }

    /// Checks if this bounding box intersects with another
    public func intersects(_ other: BoundingBox) -> Bool {
        return !(max.x < other.min.x || min.x > other.max.x ||
                 max.y < other.min.y || min.y > other.max.y ||
                 max.z < other.min.z || min.z > other.max.z)
    }
}

/// Main point cloud data structure
public struct PointCloud: Codable, Equatable {
    /// Array of points in the cloud
    public let points: [PointCloudPoint]

    /// Metadata about the point cloud
    public let metadata: PointCloudMetadata

    /// Unique identifier for the point cloud
    public let id: UUID

    /// Optional name for the point cloud
    public let name: String?

    public init(points: [PointCloudPoint],
                metadata: PointCloudMetadata,
                id: UUID = UUID(),
                name: String? = nil) {
        self.points = points
        self.metadata = metadata
        self.id = id
        self.name = name
    }

    /// Creates a point cloud from raw data
    public init?(points: [SIMD3<Float>],
                 confidences: [Float],
                 colors: [SIMD3<UInt8>]? = nil,
                 deviceModel: String,
                 scanDuration: TimeInterval,
                 qualityScore: Float,
                 id: UUID = UUID(),
                 name: String? = nil) {
        guard points.count == confidences.count else { return nil }
        if let colors = colors {
            guard points.count == colors.count else { return nil }
        }

        let pointCloudPoints = zip(points, confidences).enumerated().map { (index, element) in
            PointCloudPoint(
                position: element.0,
                confidence: element.1,
                color: colors?[index]
            )
        }

        guard let bounds = BoundingBox(points: points) else { return nil }

        let averageConfidence = confidences.reduce(0, +) / Float(confidences.count)

        let metadata = PointCloudMetadata(
            pointCount: points.count,
            bounds: bounds,
            averageConfidence: averageConfidence,
            deviceModel: deviceModel,
            scanDuration: scanDuration,
            qualityScore: qualityScore
        )

        self.init(points: pointCloudPoints, metadata: metadata, id: id, name: name)
    }

    // MARK: - Computed Properties
    public var bounds: BoundingBox {
        return metadata.bounds
    }

    public var pointCount: Int {
        return points.count
    }

    public var positions: [SIMD3<Float>] {
        return points.map { $0.position }
    }

    public var confidences: [Float] {
        return points.map { $0.confidence }
    }

    public var colors: [SIMD3<UInt8>]? {
        let colorPoints = points.compactMap { $0.color }
        return colorPoints.count == points.count ? colorPoints : nil
    }

    // MARK: - Filtering Methods
    public func filtered(confidenceThreshold: Float) -> PointCloud {
        let filteredPoints = points.filter { $0.confidence >= confidenceThreshold }
        let filteredMetadata = PointCloudMetadata(
            pointCount: filteredPoints.count,
            bounds: BoundingBox(points: filteredPoints.map { $0.position }) ?? metadata.bounds,
            averageConfidence: filteredPoints.map { $0.confidence }.reduce(0, +) / Float(filteredPoints.count),
            timestamp: metadata.timestamp,
            deviceModel: metadata.deviceModel,
            scanDuration: metadata.scanDuration,
            qualityScore: metadata.qualityScore
        )

        return PointCloud(
            points: filteredPoints,
            metadata: filteredMetadata,
            id: id,
            name: name
        )
    }

    public func filtered(boundingBox: BoundingBox) -> PointCloud {
        let filteredPoints = points.filter { boundingBox.contains($0.position) }
        let filteredMetadata = PointCloudMetadata(
            pointCount: filteredPoints.count,
            bounds: boundingBox,
            averageConfidence: filteredPoints.map { $0.confidence }.reduce(0, +) / Float(filteredPoints.count),
            timestamp: metadata.timestamp,
            deviceModel: metadata.deviceModel,
            scanDuration: metadata.scanDuration,
            qualityScore: metadata.qualityScore
        )

        return PointCloud(
            points: filteredPoints,
            metadata: filteredMetadata,
            id: id,
            name: name
        )
    }

    // MARK: - Statistics
    public func confidenceDistribution(bins: Int = 10) -> [Int] {
        var distribution = Array(repeating: 0, count: bins)
        let binSize = 1.0 / Float(bins)

        for point in points {
            let bin = min(Int(point.confidence / binSize), bins - 1)
            distribution[bin] += 1
        }

        return distribution
    }

    public func qualityMetrics() -> PointCloudQualityMetrics {
        let confidences = self.confidences
        let sortedConfidences = confidences.sorted()

        let medianConfidence = sortedConfidences[confidences.count / 2]
        let p95Confidence = sortedConfidences[Int(Float(confidences.count) * 0.95)]
        let p5Confidence = sortedConfidences[Int(Float(confidences.count) * 0.05)]

        return PointCloudQualityMetrics(
            medianConfidence: medianConfidence,
            p95Confidence: p95Confidence,
            p5Confidence: p5Confidence,
            uniformityScore: calculateUniformityScore()
        )
    }

    private func calculateUniformityScore() -> Float {
        // Simple uniformity score based on confidence variance
        let confidences = self.confidences
        let mean = confidences.reduce(0, +) / Float(confidences.count)
        let variance = confidences.reduce(0) { $0 + pow($1 - mean, 2) } / Float(confidences.count)
        let uniformity = 1.0 / (1.0 + variance) // Higher score for lower variance
        return uniformity
    }
}

/// Quality metrics for point cloud analysis
public struct PointCloudQualityMetrics: Codable, Equatable {
    /// Median confidence value
    public let medianConfidence: Float

    /// 95th percentile confidence value
    public let p95Confidence: Float

    /// 5th percentile confidence value
    public let p5Confidence: Float

    /// Uniformity score (0.0 to 1.0, higher is better)
    public let uniformityScore: Float

    public init(medianConfidence: Float, p95Confidence: Float, p5Confidence: Float, uniformityScore: Float) {
        self.medianConfidence = medianConfidence
        self.p95Confidence = p95Confidence
        self.p5Confidence = p5Confidence
        self.uniformityScore = uniformityScore
    }
}
