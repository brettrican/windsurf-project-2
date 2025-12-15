//
//  ProjectContextManager.swift
//  InteriorAI
//
//  Manages project context throughout the design process using vector database
//

import Foundation
import Combine

/// Project context manager for maintaining design coherence
public final class ProjectContextManager {
    // MARK: - Singleton
    public static let shared = ProjectContextManager()

    // MARK: - Properties
    private let vectorDatabase = VectorDatabase.shared
    private let processingQueue = DispatchQueue(label: "com.interiorai.context.processing", qos: .userInitiated)

    private var activeProjectId: UUID?
    private var contextCache = [UUID: StoredContext]()

    // Publishers
    public let contextUpdated = PassthroughSubject<UUID, Never>()
    public let alignmentChecked = PassthroughSubject<DesignAlignmentResult, Never>()

    // MARK: - Initialization
    private init() {
        Logger.shared.info("ProjectContextManager initialized")
    }

    // MARK: - Project Management

    /// Starts a new design project
    /// - Parameters:
    ///   - projectId: Optional project identifier
    ///   - initialGoal: Initial design goal description
    /// - Throws: ProjectContextError if project creation fails
    public func startProject(projectId: UUID? = nil, initialGoal: String) throws {
        let newProjectId = projectId ?? UUID()
        Logger.shared.info("Starting new project: \(newProjectId)")

        // Create initial design goal context
        let goalContext = StoredContext(
            type: .designGoal,
            title: "Project Goal",
            description: initialGoal,
            embedding: generateTextEmbedding(initialGoal),
            metadata: ["phase": "initialization"],
            projectId: newProjectId
        )

        try vectorDatabase.storeContext(goalContext)
        activeProjectId = newProjectId
        contextCache[goalContext.id] = goalContext

        contextUpdated.send(newProjectId)
        Logger.shared.info("Project started successfully")
    }

    /// Ends the current project
    /// - Throws: ProjectContextError if project closure fails
    public func endProject() throws {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        Logger.shared.info("Ending project: \(projectId)")

        // Store final project summary
        let summaryContext = generateProjectSummary(projectId: projectId)
        try vectorDatabase.storeContext(summaryContext)

        activeProjectId = nil
        contextCache.removeAll()

        Logger.shared.info("Project ended successfully")
    }

    // MARK: - Context Logging

    /// Logs a scan context
    /// - Parameter pointCloud: The scanned point cloud
    /// - Throws: ProjectContextError if logging fails
    public func logScanContext(_ pointCloud: PointCloud) throws {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let scanContext = StoredContext(
            type: .scanContext,
            title: "Room Scan",
            description: "LiDAR scan with \(pointCloud.pointCount) points, dimensions: \(String(format: "%.1fx%.1fx%.1f", pointCloud.bounds.size.x, pointCloud.bounds.size.y, pointCloud.bounds.size.z))m",
            embedding: generatePointCloudEmbedding(pointCloud),
            metadata: [
                "pointCount": String(pointCloud.pointCount),
                "dimensions": "\(pointCloud.bounds.size.x),\(pointCloud.bounds.size.y),\(pointCloud.bounds.size.z)",
                "qualityScore": String(pointCloud.metadata.qualityScore),
                "scanDuration": String(pointCloud.metadata.scanDuration)
            ],
            projectId: projectId
        )

        try vectorDatabase.storeContext(scanContext)
        contextCache[scanContext.id] = scanContext

        contextUpdated.send(projectId)
        Logger.shared.info("Scan context logged")
    }

    /// Logs detected furniture context
    /// - Parameter detectionResult: The furniture detection results
    /// - Throws: ProjectContextError if logging fails
    public func logFurnitureDetection(_ detectionResult: FurnitureDetectionResult) throws {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let categories = detectionResult.detections.map { $0.category.displayName }.joined(separator: ", ")
        let detectionContext = StoredContext(
            type: .furniturePlacement,
            title: "Furniture Detection",
            description: "Detected \(detectionResult.detections.count) furniture items: \(categories)",
            embedding: generateDetectionEmbedding(detectionResult),
            metadata: [
                "detectionCount": String(detectionResult.detections.count),
                "categories": categories,
                "confidence": String(detectionResult.averageConfidence),
                "processingTime": String(detectionResult.processingTime)
            ],
            projectId: projectId
        )

        try vectorDatabase.storeContext(detectionContext)
        contextCache[detectionContext.id] = detectionContext

        contextUpdated.send(projectId)
        Logger.shared.info("Furniture detection context logged")
    }

    /// Logs design recommendations
    /// - Parameter recommendation: The design recommendation
    /// - Throws: ProjectContextError if logging fails
    public func logDesignRecommendation(_ recommendation: DesignRecommendation) throws {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let recommendationContext = StoredContext(
            type: .recommendation,
            title: recommendation.title,
            description: recommendation.description,
            embedding: generateRecommendationEmbedding(recommendation),
            metadata: [
                "suggestions": String(recommendation.suggestions.count),
                "improvements": String(recommendation.layoutImprovements.count),
                "confidence": String(recommendation.confidence),
                "hasColorScheme": String(recommendation.colorScheme != nil)
            ],
            projectId: projectId
        )

        try vectorDatabase.storeContext(recommendationContext)
        contextCache[recommendationContext.id] = recommendationContext

        contextUpdated.send(projectId)
        Logger.shared.info("Design recommendation context logged")
    }

    /// Logs furniture placement changes
    /// - Parameter placements: Current furniture placements
    /// - Throws: ProjectContextError if logging fails
    public func logFurniturePlacement(_ placements: [FurniturePlacementContext]) throws {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let placementDescriptions = placements.map {
            "\($0.furniture.category.displayName) at (\(String(format: "%.1f", $0.position.x)), \(String(format: "%.1f", $0.position.z)))"
        }.joined(separator: "; ")

        let placementContext = StoredContext(
            type: .furniturePlacement,
            title: "Furniture Arrangement",
            description: "Current furniture placement: \(placementDescriptions)",
            embedding: generatePlacementEmbedding(placements),
            metadata: [
                "itemCount": String(placements.count),
                "arrangement": placementDescriptions
            ],
            projectId: projectId
        )

        try vectorDatabase.storeContext(placementContext)
        contextCache[placementContext.id] = placementContext

        contextUpdated.send(projectId)
        Logger.shared.info("Furniture placement context logged")
    }

    // MARK: - Context Retrieval

    /// Retrieves all contexts for the current project
    /// - Returns: Array of stored contexts
    /// - Throws: ProjectContextError if retrieval fails
    public func getProjectContexts() throws -> [StoredContext] {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        return try vectorDatabase.searchContexts(
            ContextQuery(projectId: projectId, limit: 1000)
        ).contexts
    }

    /// Retrieves contexts of specific types
    /// - Parameter types: Context types to retrieve
    /// - Returns: Array of matching contexts
    /// - Throws: ProjectContextError if retrieval fails
    public func getContexts(ofTypes types: Set<ContextType>) throws -> [StoredContext] {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        return try vectorDatabase.searchContexts(
            ContextQuery(types: types, projectId: projectId, limit: 1000)
        ).contexts
    }

    /// Finds similar contexts using semantic search
    /// - Parameter query: Text query to search for
    /// - Returns: Array of similar contexts with relevance scores
    /// - Throws: ProjectContextError if search fails
    public func findSimilarContexts(query: String) throws -> [StoredContext] {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        // Generate embedding for the query
        let queryEmbedding = generateTextEmbedding(query)

        return try vectorDatabase.searchContexts(
            ContextQuery(embedding: queryEmbedding, projectId: projectId, limit: 10)
        ).contexts
    }

    // MARK: - Design Alignment

    /// Checks if current design aligns with project goals
    /// - Parameter currentDesign: Vector representation of current design state
    /// - Returns: Alignment analysis result
    /// - Throws: ProjectContextError if alignment check fails
    public func checkDesignAlignment(currentDesign: VectorEmbedding) throws -> DesignAlignmentResult {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let result = try vectorDatabase.validateDesignAlignment(
            currentDesign: currentDesign,
            projectId: projectId
        )

        alignmentChecked.send(result)
        Logger.shared.info("Design alignment checked: \(result.isAligned ? "aligned" : "misaligned") (score: \(String(format: "%.2f", result.alignmentScore)))")

        return result
    }

    /// Gets design evolution history
    /// - Returns: Chronological list of design contexts
    /// - Throws: ProjectContextError if retrieval fails
    public func getDesignEvolution() throws -> [StoredContext] {
        let evolutionContexts = try getContexts(ofTypes: [.designEvolution, .scanContext, .recommendation])
        return evolutionContexts.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Context Vector Generation

    private func generateTextEmbedding(_ text: String) -> VectorEmbedding {
        // Simplified text embedding - in production this would use a proper NLP model
        var vector = VectorEmbedding(dimensions: VectorConstants.maxVectorDimensions)
        let textData = text.data(using: .utf8) ?? Data()

        // Simple hash-based embedding for demonstration
        for (index, byte) in textData.enumerated() {
            let vectorIndex = index % vector.vector.count
            vector.vector[vectorIndex] = Float(byte) / 255.0
        }

        return vector
    }

    private func generatePointCloudEmbedding(_ pointCloud: PointCloud) -> VectorEmbedding {
        // Generate embedding from point cloud statistics
        var vector = VectorEmbedding(dimensions: VectorConstants.maxVectorDimensions)

        // Use point cloud properties as embedding features
        vector.vector[0] = Float(pointCloud.pointCount) / 100000.0 // Normalize point count
        vector.vector[1] = pointCloud.metadata.averageConfidence
        vector.vector[2] = pointCloud.metadata.qualityScore
        vector.vector[3] = pointCloud.bounds.size.x / 10.0 // Normalize dimensions
        vector.vector[4] = pointCloud.bounds.size.y / 10.0
        vector.vector[5] = pointCloud.bounds.size.z / 10.0

        return vector
    }

    private func generateDetectionEmbedding(_ detectionResult: FurnitureDetectionResult) -> VectorEmbedding {
        var vector = VectorEmbedding(dimensions: VectorConstants.maxVectorDimensions)

        // Use detection statistics as embedding features
        vector.vector[0] = Float(detectionResult.detectionCount) / 50.0 // Normalize count
        vector.vector[1] = detectionResult.averageConfidence
        vector.vector[2] = Float(detectionResult.processingTime) / 10.0 // Normalize time

        // Category distribution
        let categoryCounts = detectionResult.categoryDistribution()
        for (index, category) in FurnitureCategory.allCases.enumerated() {
            if index < 10 { // Limit to first 10 categories
                vector.vector[3 + index] = Float(categoryCounts[category] ?? 0) / 20.0
            }
        }

        return vector
    }

    private func generateRecommendationEmbedding(_ recommendation: DesignRecommendation) -> VectorEmbedding {
        var vector = VectorEmbedding(dimensions: VectorConstants.maxVectorDimensions)

        // Use recommendation properties as embedding features
        vector.vector[0] = Float(recommendation.suggestions.count) / 20.0
        vector.vector[1] = Float(recommendation.layoutImprovements.count) / 10.0
        vector.vector[2] = recommendation.confidence
        vector.vector[3] = recommendation.colorScheme != nil ? 1.0 : 0.0

        return vector
    }

    private func generatePlacementEmbedding(_ placements: [FurniturePlacementContext]) -> VectorEmbedding {
        var vector = VectorEmbedding(dimensions: VectorConstants.maxVectorDimensions)

        // Use placement statistics as embedding features
        vector.vector[0] = Float(placements.count) / 50.0

        // Calculate center of mass
        if !placements.isEmpty {
            let center = placements.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.position } / Float(placements.count)
            vector.vector[1] = center.x / 10.0 // Normalize position
            vector.vector[2] = center.y / 10.0
            vector.vector[3] = center.z / 10.0
        }

        return vector
    }

    // MARK: - Project Summary

    private func generateProjectSummary(projectId: UUID) -> StoredContext {
        do {
            let allContexts = try getProjectContexts()
            let designGoals = allContexts.filter { $0.type == .designGoal }
            let scans = allContexts.filter { $0.type == .scanContext }
            let recommendations = allContexts.filter { $0.type == .recommendation }

            let summary = """
            Project Summary:
            - Design Goals: \(designGoals.count)
            - Room Scans: \(scans.count)
            - Recommendations Generated: \(recommendations.count)
            - Total Contexts: \(allContexts.count)
            - Project Duration: \(calculateProjectDuration(contexts: allContexts))
            """

            return StoredContext(
                type: .designEvolution,
                title: "Project Summary",
                description: summary,
                embedding: generateTextEmbedding(summary),
                metadata: [
                    "goals": String(designGoals.count),
                    "scans": String(scans.count),
                    "recommendations": String(recommendations.count),
                    "totalContexts": String(allContexts.count)
                ],
                projectId: projectId
            )
        } catch {
            Logger.shared.error("Failed to generate project summary", error: error, category: .general)
            return StoredContext(
                type: .designEvolution,
                title: "Project Summary",
                description: "Summary generation failed",
                embedding: VectorEmbedding(),
                projectId: projectId
            )
        }
    }

    private func calculateProjectDuration(contexts: [StoredContext]) -> String {
        guard let firstContext = contexts.min(by: { $0.timestamp < $1.timestamp }),
              let lastContext = contexts.max(by: { $0.timestamp < $1.timestamp }) else {
            return "Unknown"
        }

        let duration = lastContext.timestamp.timeIntervalSince(firstContext.timestamp)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        return "\(hours)h \(minutes)m"
    }

    // MARK: - Context Coherence

    /// Validates context coherence across the project
    /// - Returns: Coherence analysis result
    /// - Throws: ProjectContextError if analysis fails
    public func validateContextCoherence() throws -> ContextCoherenceResult {
        guard let projectId = activeProjectId else {
            throw ProjectContextError.noActiveProject
        }

        let contexts = try getProjectContexts()

        // Check for conflicting recommendations
        let recommendations = contexts.filter { $0.type == .recommendation }
        let conflicts = analyzeRecommendationConflicts(recommendations)

        // Check design goal alignment
        let alignmentScore = try calculateOverallAlignment(contexts: contexts)

        // Generate coherence score
        let coherenceScore = calculateCoherenceScore(conflicts: conflicts.count, alignmentScore: alignmentScore)

        return ContextCoherenceResult(
            coherenceScore: coherenceScore,
            conflicts: conflicts,
            alignmentScore: alignmentScore,
            recommendations: generateCoherenceRecommendations(conflicts: conflicts, alignmentScore: alignmentScore)
        )
    }

    private func analyzeRecommendationConflicts(_ recommendations: [StoredContext]) -> [ContextConflict] {
        // Analyze for conflicting recommendations (simplified)
        var conflicts: [ContextConflict] = []

        // Check for contradictory suggestions
        for i in 0..<recommendations.count {
            for j in i+1..<recommendations.count {
                if recommendations[i].embedding.cosineSimilarity(with: recommendations[j].embedding) < 0.3 {
                    conflicts.append(ContextConflict(
                        context1: recommendations[i],
                        context2: recommendations[j],
                        description: "Conflicting design recommendations detected",
                        severity: .medium
                    ))
                }
            }
        }

        return conflicts
    }

    private func calculateOverallAlignment(contexts: [StoredContext]) throws -> Float {
        let designGoals = contexts.filter { $0.type == .designGoal }
        let recommendations = contexts.filter { $0.type == .recommendation }

        guard !designGoals.isEmpty else { return 0.5 }

        var totalAlignment = Float(0)
        var count = 0

        for goal in designGoals {
            for recommendation in recommendations {
                let alignment = goal.embedding.cosineSimilarity(with: recommendation.embedding)
                totalAlignment += alignment
                count += 1
            }
        }

        return count > 0 ? totalAlignment / Float(count) : 0.5
    }

    private func calculateCoherenceScore(conflicts: Int, alignmentScore: Float) -> Float {
        let conflictPenalty = min(Float(conflicts) * 0.1, 0.4)
        return max(alignmentScore - conflictPenalty, 0.0)
    }

    private func generateCoherenceRecommendations(conflicts: [ContextConflict], alignmentScore: Float) -> [String] {
        var recommendations: [String] = []

        if !conflicts.isEmpty {
            recommendations.append("Resolve \(conflicts.count) conflicting design recommendations")
        }

        if alignmentScore < 0.6 {
            recommendations.append("Review design goals to ensure consistency across recommendations")
        }

        if recommendations.isEmpty {
            recommendations.append("Design context remains coherent and well-aligned")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

/// Context conflict between design elements
public struct ContextConflict {
    public let context1: StoredContext
    public let context2: StoredContext
    public let description: String
    public let severity: ConflictSeverity

    public enum ConflictSeverity {
        case low, medium, high, critical
    }
}

/// Context coherence analysis result
public struct ContextCoherenceResult {
    public let coherenceScore: Float
    public let conflicts: [ContextConflict]
    public let alignmentScore: Float
    public let recommendations: [String]
}

/// Project context errors
public enum ProjectContextError: LocalizedError {
    case noActiveProject
    case projectNotFound(UUID)
    case contextStorageFailed(String)
    case contextRetrievalFailed(String)
    case alignmentCheckFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noActiveProject:
            return "No active project to perform operation on"
        case .projectNotFound(let projectId):
            return "Project with ID \(projectId) not found"
        case .contextStorageFailed(let reason):
            return "Failed to store context: \(reason)"
        case .contextRetrievalFailed(let reason):
            return "Failed to retrieve context: \(reason)"
        case .alignmentCheckFailed(let reason):
            return "Failed to check design alignment: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noActiveProject:
            return "Start a new project before performing this operation"
        case .projectNotFound:
            return "Verify the project ID and try again"
        case .contextStorageFailed, .contextRetrievalFailed:
            return "Check available storage and try again"
        case .alignmentCheckFailed:
            return "Try again or contact support if the problem persists"
        }
    }
}

