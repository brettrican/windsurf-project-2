//
//  VectorDatabase.swift
//  InteriorAI
//
//  Vector database for storing and retrieving project contexts and design patterns
//

import Foundation
import Combine
import simd

/// Represents a vector embedding for similarity search
public struct VectorEmbedding: Codable, Equatable {
    /// The vector data (512 dimensions as per constants)
    public var vector: [Float]

    /// Dimensionality of the vector
    public var dimensions: Int {
        return vector.count
    }

    /// Normalized version of the vector for cosine similarity
    public var normalized: VectorEmbedding {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return self }

        let normalizedVector = vector.map { $0 / magnitude }
        return VectorEmbedding(vector: normalizedVector)
    }

    public init(vector: [Float]) {
        self.vector = vector
    }

    public init(dimensions: Int = VectorConstants.maxVectorDimensions) {
        self.vector = Array(repeating: 0.0, count: dimensions)
    }

    /// Calculates cosine similarity with another vector
    public func cosineSimilarity(with other: VectorEmbedding) -> Float {
        guard dimensions == other.dimensions else { return 0.0 }

        let normalizedSelf = self.normalized
        let normalizedOther = other.normalized

        return zip(normalizedSelf.vector, normalizedOther.vector)
            .map(*)
            .reduce(0, +)
    }

    /// Calculates Euclidean distance with another vector
    public func euclideanDistance(to other: VectorEmbedding) -> Float {
        guard dimensions == other.dimensions else { return Float.greatestFiniteMagnitude }

        let squaredDifferences = zip(vector, other.vector).map { ($0 - $1) * ($0 - $1) }
        return sqrt(squaredDifferences.reduce(0, +))
    }
}

/// Context types for different kinds of stored information
public enum ContextType: String, Codable {
    case designGoal = "design_goal"
    case scanContext = "scan_context"
    case recommendation = "recommendation"
    case furniturePlacement = "furniture_placement"
    case userPreference = "user_preference"
    case designEvolution = "design_evolution"
}

/// A stored context with vector embedding for similarity search
public struct StoredContext: Identifiable, Codable, Equatable {
    /// Unique identifier
    public let id: UUID

    /// Type of context
    public let type: ContextType

    /// Human-readable title
    public let title: String

    /// Detailed description
    public let description: String

    /// Vector embedding for similarity search
    public let embedding: VectorEmbedding

    /// Additional metadata
    public let metadata: [String: String]

    /// Timestamp when created
    public let timestamp: Date

    /// Associated project or scan ID
    public let projectId: UUID?

    /// Relevance score (used for search results)
    public var relevanceScore: Float?

    public init(id: UUID = UUID(),
                type: ContextType,
                title: String,
                description: String,
                embedding: VectorEmbedding,
                metadata: [String: String] = [:],
                timestamp: Date = Date(),
                projectId: UUID? = nil,
                relevanceScore: Float? = nil) {
        self.id = id
        self.type = type
               self.title = title
        self.description = description
        self.embedding = embedding
        self.metadata = metadata
        self.timestamp = timestamp
        self.projectId = projectId
        self.relevanceScore = relevanceScore
    }
}

/// Search query for finding similar contexts
public struct ContextQuery {
    /// Query text to search for
    public let text: String?

    /// Vector embedding for similarity search
    public let embedding: VectorEmbedding?

    /// Types of contexts to search (nil means all types)
    public let types: Set<ContextType>?

    /// Project ID to filter results
    public let projectId: UUID?

    /// Maximum number of results
    public let limit: Int

    /// Minimum similarity threshold
    public let threshold: Float

    public init(text: String? = nil,
                embedding: VectorEmbedding? = nil,
                types: Set<ContextType>? = nil,
                projectId: UUID? = nil,
                limit: Int = VectorConstants.maxSearchResults,
                threshold: Float = VectorConstants.similarityThreshold) {
        self.text = text
        self.embedding = embedding
        self.types = types
        self.projectId = projectId
        self.limit = limit
        self.threshold = threshold
    }
}

/// Search results with similarity scores
public struct ContextSearchResult {
    /// Found contexts with relevance scores
    public let contexts: [StoredContext]

    /// Total number of matches found
    public let totalMatches: Int

    /// Search execution time
    public let searchTime: TimeInterval

    public init(contexts: [StoredContext], totalMatches: Int, searchTime: TimeInterval) {
        self.contexts = contexts
        self.totalMatches = totalMatches
        self.searchTime = searchTime
    }
}

/// Comprehensive vector database for project context management
public final class VectorDatabase {
    // MARK: - Singleton
    public static let shared = VectorDatabase()

    // MARK: - Properties
    private let queue: DispatchQueue
    private var contexts: [UUID: StoredContext] = [:]
    private var isInitialized = true

    // MARK: - Initialization
    private init() {
        self.queue = DispatchQueue(label: "com.interiorai.vectordb", qos: .userInitiated)
        Logger.shared.info("Vector database initialized successfully")
    }

    // MARK: - Public Interface

    /// Stores a new context in the vector database
    /// - Parameter context: The context to store
    /// - Throws: VectorDatabaseError if storage fails
    public func storeContext(_ context: StoredContext) {
        queue.sync {
            contexts[context.id] = context
            Logger.shared.info("Context stored successfully: \(context.id)")
        }
    }

    /// Stores multiple contexts in batch
    /// - Parameter contexts: Array of contexts to store
    /// - Throws: VectorDatabaseError if storage fails
    public func storeContexts(_ contexts: [StoredContext]) {
        queue.sync {
            for context in contexts {
                self.contexts[context.id] = context
            }
            Logger.shared.info("Batch stored \(contexts.count) contexts successfully")
        }
    }

    /// Retrieves a context by ID
    /// - Parameter id: The context ID
    /// - Returns: The stored context
    /// - Throws: VectorDatabaseError if retrieval fails
    public func retrieveContext(id: UUID) throws -> StoredContext {
        let context: StoredContext? = queue.sync {
            return contexts[id]
        }
        guard let context else {
            throw VectorDatabaseError.contextNotFound(id)
        }
        return context
    }

    /// Searches for similar contexts using vector similarity
    /// - Parameter query: The search query
    /// - Returns: Search results with similarity scores
    /// - Throws: VectorDatabaseError if search fails
    public func searchContexts(_ query: ContextQuery) throws -> ContextSearchResult {
        let startTime = Date()

        let results: [StoredContext] = queue.sync {
            var candidates = Array(contexts.values)

            // Filter by types
            if let types = query.types, !types.isEmpty {
                candidates = candidates.filter { types.contains($0.type) }
            }

            // Filter by project ID
            if let projectId = query.projectId {
                candidates = candidates.filter { $0.projectId == projectId }
            }

            // Calculate similarities and rank results
            var results = candidates.map { context -> StoredContext in
                var context = context
                if let queryEmbedding = query.embedding {
                    let similarity = context.embedding.cosineSimilarity(with: queryEmbedding)
                    context.relevanceScore = similarity
                } else {
                    context.relevanceScore = 0.0
                }
                return context
            }

            // Filter by threshold and sort by relevance
            results = results
                .filter { ($0.relevanceScore ?? 0.0) >= query.threshold }
                .sorted { ($0.relevanceScore ?? 0.0) > ($1.relevanceScore ?? 0.0) }
                .prefix(query.limit)
                .map { $0 }

            return Array(results)
        }

        let searchTime = Date().timeIntervalSince(startTime)
        Logger.shared.info("Vector search completed in \(String(format: "%.3f", searchTime))s, found \(results.count) results")

        return ContextSearchResult(
            contexts: results,
            totalMatches: results.count,
            searchTime: searchTime
        )
    }

    /// Updates an existing context
    /// - Parameters:
    ///   - id: The context ID to update
    ///   - updates: The updated context data
    /// - Throws: VectorDatabaseError if update fails
    public func updateContext(id: UUID, updates: StoredContext) throws {
        var notFound = false
        queue.sync {
            if contexts[id] == nil {
                notFound = true
            } else {
                contexts[id] = updates
                Logger.shared.info("Context updated successfully: \(id)")
            }
        }
        if notFound {
            throw VectorDatabaseError.contextNotFound(id)
        }
    }

    /// Deletes a context by ID
    /// - Parameter id: The context ID to delete
    /// - Throws: VectorDatabaseError if deletion fails
    public func deleteContext(id: UUID) throws {
        var removed: StoredContext?
        queue.sync {
            removed = contexts.removeValue(forKey: id)
            if removed != nil {
                Logger.shared.info("Context deleted successfully: \(id)")
            }
        }
        guard removed != nil else {
            throw VectorDatabaseError.contextNotFound(id)
        }
    }

    /// Deletes all contexts for a specific project
    /// - Parameter projectId: The project ID
    /// - Throws: VectorDatabaseError if deletion fails
    public func deleteContexts(forProject projectId: UUID) {
        queue.sync {
            let initialCount = contexts.count
            contexts = contexts.filter { $0.value.projectId != projectId }
            let deletedCount = initialCount - contexts.count
            Logger.shared.info("Deleted \(deletedCount) contexts for project: \(projectId)")
        }
    }

    /// Gets statistics about stored contexts
    /// - Returns: Database statistics
    public func getStatistics() -> DatabaseStatistics {
        return queue.sync {
            let totalContexts = contexts.count
            var typeCounts: [ContextType: Int] = [:]

            for context in contexts.values {
                typeCounts[context.type, default: 0] += 1
            }

            return DatabaseStatistics(
                totalContexts: totalContexts,
                contextsByType: typeCounts,
                databaseSize: Int64(totalContexts * 1024) // Rough estimate
            )
        }
    }

    // MARK: - Design Goal Validation

    /// Validates if a current design aligns with stored project goals
    /// - Parameters:
    ///   - currentDesign: Vector representation of current design
    ///   - projectId: Project ID to validate against
    /// - Returns: Validation result with alignment score
    public func validateDesignAlignment(currentDesign: VectorEmbedding, projectId: UUID) throws -> DesignAlignmentResult {
        let query = ContextQuery(
            embedding: currentDesign,
            types: [.designGoal],
            projectId: projectId,
            limit: 10,
            threshold: 0.3
        )

        let results = try searchContexts(query)

        guard let bestMatch = results.contexts.first else {
            return DesignAlignmentResult(
                isAligned: false,
                alignmentScore: 0.0,
                recommendedAdjustments: ["No design goals found for this project"]
            )
        }

        let alignmentScore = bestMatch.relevanceScore ?? 0.0
        let isAligned = alignmentScore >= 0.7

        // Generate recommendations based on misalignment
        let recommendations = generateAlignmentRecommendations(
            alignmentScore: alignmentScore,
            bestMatch: bestMatch
        )

        return DesignAlignmentResult(
            isAligned: isAligned,
            alignmentScore: alignmentScore,
            recommendedAdjustments: recommendations
        )
    }

    /// Finds similar past designs for reference
    /// - Parameters:
    ///   - currentDesign: Vector representation of current design
    ///   - projectId: Optional project ID filter
    /// - Returns: Array of similar designs
    public func findSimilarDesigns(currentDesign: VectorEmbedding, projectId: UUID? = nil) throws -> [StoredContext] {
        let query = ContextQuery(
            embedding: currentDesign,
            types: [.designEvolution, .scanContext],
            projectId: projectId,
            limit: 5,
            threshold: 0.5
        )

        let results = try searchContexts(query)
        return results.contexts
    }

    // MARK: - Private Helper Methods

    private func getDatabaseSize() -> Int64 {
        // Since we're using in-memory storage for iOS, return estimated size
        // In a real implementation, this would calculate actual storage size
        let estimatedSizePerContext = Int64(1024) // 1KB per context
        return Int64(contexts.count) * estimatedSizePerContext
    }

    private func generateAlignmentRecommendations(alignmentScore: Float, bestMatch: StoredContext) -> [String] {
        var recommendations: [String] = []

        if alignmentScore < 0.5 {
            recommendations.append("Current design significantly deviates from project goals")
            recommendations.append("Consider reviewing the original design objectives in: \(bestMatch.title)")
        } else if alignmentScore < 0.7 {
            recommendations.append("Current design partially aligns with project goals")
            recommendations.append("Consider incorporating elements from: \(bestMatch.title)")
        } else {
            recommendations.append("Design is well-aligned with project goals")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

/// Database statistics
public struct DatabaseStatistics {
    public let totalContexts: Int
    public let contextsByType: [ContextType: Int]
    public let databaseSize: Int64
}

/// Design alignment validation result
public struct DesignAlignmentResult {
    public let isAligned: Bool
    public let alignmentScore: Float
    public let recommendedAdjustments: [String]
}



// MARK: - Vector Database Errors

public enum VectorDatabaseError: LocalizedError {
    case contextNotFound(UUID)
    case invalidEmbedding(String)
    case storageFailed(String)
    case searchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .contextNotFound(let id):
            return "Context not found with ID: \(id)"
        case .invalidEmbedding(let reason):
            return "Invalid embedding: \(reason)"
        case .storageFailed(let reason):
            return "Storage operation failed: \(reason)"
        case .searchFailed(let reason):
            return "Search operation failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .contextNotFound:
            return "Verify the context ID and try again."
        case .invalidEmbedding:
            return "Check the embedding dimensions and format."
        case .storageFailed:
            return "Check available storage space and try again."
        case .searchFailed:
            return "Try adjusting search parameters or contact support."
        }
    }
}

