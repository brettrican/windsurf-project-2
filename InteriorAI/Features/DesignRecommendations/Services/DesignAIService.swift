//
//  DesignAIService.swift
//  InteriorAI
//
//  AI-powered design recommendation service
//

import Foundation
import CoreML
import Vision
import Combine
import simd

/// Design recommendation request
public struct DesignRecommendationRequest {
    public let pointCloud: PointCloud?
    public let detectedFurniture: [DetectedFurniture]
    public let roomDimensions: RoomDimensions?
    public let userPreferences: UserDesignPreferences?
    public let existingFurniture: [FurniturePlacementContext]

    public init(pointCloud: PointCloud? = nil,
                detectedFurniture: [DetectedFurniture] = [],
                roomDimensions: RoomDimensions? = nil,
                userPreferences: UserDesignPreferences? = nil,
                existingFurniture: [FurniturePlacementContext] = []) {
        self.pointCloud = pointCloud
        self.detectedFurniture = detectedFurniture
        self.roomDimensions = roomDimensions
        self.userPreferences = userPreferences
        self.existingFurniture = existingFurniture
    }
}

/// Design recommendation result
public struct DesignRecommendation {
    public let id: UUID
    public let title: String
    public let description: String
    public let suggestions: [FurnitureSuggestion]
    public let layoutImprovements: [LayoutImprovement]
    public let colorScheme: ColorScheme?
    public let confidence: Float
    public let reasoning: String
    public let timestamp: Date

    public init(id: UUID = UUID(),
                title: String,
                description: String,
                suggestions: [FurnitureSuggestion],
                layoutImprovements: [LayoutImprovement],
                colorScheme: ColorScheme? = nil,
                confidence: Float,
                reasoning: String,
                timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.suggestions = suggestions
        self.layoutImprovements = layoutImprovements
        self.colorScheme = colorScheme
        self.confidence = confidence
        self.reasoning = reasoning
        self.timestamp = timestamp
    }
}

/// Furniture suggestion
public struct FurnitureSuggestion {
    public let category: FurnitureCategory
    public let position: SIMD3<Float>
    public let orientation: SIMD3<Float>
    public let reason: String
    public let confidence: Float

    public init(category: FurnitureCategory,
                position: SIMD3<Float>,
                orientation: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                reason: String,
                confidence: Float) {
        self.category = category
        self.position = position
        self.orientation = orientation
        self.reason = reason
        self.confidence = confidence
    }
}

/// Layout improvement suggestion
public struct LayoutImprovement {
    public let type: ImprovementType
    public let description: String
    public let affectedArea: SIMD3<Float>
    public let improvement: String

    public enum ImprovementType {
        case spacing
        case trafficFlow
        case lighting
        case balance
        case functionality
    }

    public init(type: ImprovementType,
                description: String,
                affectedArea: SIMD3<Float>,
                improvement: String) {
        self.type = type
        self.description = description
        self.affectedArea = affectedArea
        self.improvement = improvement
    }
}

/// Color scheme recommendation
public struct ColorScheme {
    public let primaryColor: SIMD3<Float>
    public let secondaryColor: SIMD3<Float>
    public let accentColor: SIMD3<Float>
    public let wallColor: SIMD3<Float>
    public let flooringColor: SIMD3<Float>
    public let reasoning: String

    public init(primaryColor: SIMD3<Float>,
                secondaryColor: SIMD3<Float>,
                accentColor: SIMD3<Float>,
                wallColor: SIMD3<Float>,
                flooringColor: SIMD3<Float>,
                reasoning: String) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.wallColor = wallColor
        self.flooringColor = flooringColor
        self.reasoning = reasoning
    }
}

/// Room dimensions
public struct RoomDimensions {
    public let width: Float
    public let height: Float
    public let depth: Float
    public let area: Float

    public init(width: Float, height: Float, depth: Float) {
        self.width = width
        self.height = height
        self.depth = depth
        self.area = width * depth
    }
}

/// User design preferences
public struct UserDesignPreferences {
    public let style: FurnitureStyle
    public let colorPreferences: Set<FurnitureColor>
    public let budget: PriceRange?
    public let roomPurpose: RoomPurpose
    public let lighting: LightingPreference

    public enum PriceRange {
        case budget, moderate, premium, luxury
    }

    public enum RoomPurpose {
        case living, bedroom, dining, office, mixed
    }

    public enum LightingPreference {
        case bright, moderate, dim, natural
    }

    public init(style: FurnitureStyle,
                colorPreferences: Set<FurnitureColor> = [],
                budget: PriceRange? = nil,
                roomPurpose: RoomPurpose = .mixed,
                lighting: LightingPreference = .moderate) {
        self.style = style
        self.colorPreferences = colorPreferences
        self.budget = budget
        self.roomPurpose = roomPurpose
        self.lighting = lighting
    }
}

/// AI service for design recommendations
public final class DesignAIService {
    // MARK: - Singleton
    public static let shared = DesignAIService()

    // MARK: - Properties
    private let processingQueue = DispatchQueue(label: "com.interiorai.design.processing", qos: .userInitiated)
    private let modelQueue = DispatchQueue(label: "com.interiorai.design.model", qos: .background)

    private var recommendationModel: VNCoreMLModel?
    private var isInitialized = false

    // Publishers
    public let recommendationProgress = PassthroughSubject<Double, Never>()
    public let recommendationCompleted = PassthroughSubject<Result<DesignRecommendation, DesignAIError>, Never>()

    // MARK: - Initialization
    private init() {
        setupModels()
    }

    // MARK: - Public Interface

    /// Generates design recommendations based on room analysis
    /// - Parameter request: The design recommendation request
    /// - Returns: Publisher that emits design recommendations
    public func generateRecommendations(for request: DesignRecommendationRequest) -> AnyPublisher<DesignRecommendation, DesignAIError> {
        Logger.shared.info("Generating design recommendations")

        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }

            self.processingQueue.async {
                self.performRecommendationGeneration(request: request) { result in
                    switch result {
                    case .success(let recommendation):
                        Logger.shared.info("Design recommendations generated successfully")
                        promise(.success(recommendation))
                    case .failure(let error):
                        Logger.shared.error("Design recommendation generation failed", error: error, category: .general)
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Analyzes room layout and provides improvement suggestions
    /// - Parameter furniture: Current furniture placement
    /// - Returns: Layout analysis result
    public func analyzeRoomLayout(furniture: [FurniturePlacementContext]) -> RoomLayoutAnalysis {
        Logger.shared.info("Analyzing room layout with \(furniture.count) items")

        // Analyze spacing between furniture
        let spacingIssues = analyzeFurnitureSpacing(furniture)

        // Analyze traffic flow
        let trafficFlowIssues = analyzeTrafficFlow(furniture)

        // Analyze balance and focal points
        let balanceAnalysis = analyzeRoomBalance(furniture)

        // Generate overall score
        let overallScore = calculateOverallLayoutScore(spacingIssues: spacingIssues.count,
                                                      trafficIssues: trafficFlowIssues.count,
                                                      balanceScore: balanceAnalysis.balanceScore)

        return RoomLayoutAnalysis(
            spacingIssues: spacingIssues,
            trafficFlowIssues: trafficFlowIssues,
            balanceAnalysis: balanceAnalysis,
            overallScore: overallScore,
            recommendations: generateLayoutRecommendations(spacingIssues: spacingIssues,
                                                        trafficIssues: trafficFlowIssues,
                                                        balanceAnalysis: balanceAnalysis)
        )
    }

    /// Generates color scheme recommendations
    /// - Parameters:
    ///   - furniture: Detected furniture items
    ///   - preferences: User color preferences
    /// - Returns: Recommended color scheme
    public func generateColorScheme(for furniture: [DetectedFurniture],
                                   preferences: UserDesignPreferences?) -> ColorScheme {
        Logger.shared.info("Generating color scheme recommendations")

        // Analyze existing colors in furniture
        let existingColors = extractExistingColors(from: furniture)

        // Consider user preferences
        let preferredColors = preferences?.colorPreferences ?? []

        // Generate harmonious color scheme
        let colorScheme = createHarmoniousColorScheme(existingColors: existingColors,
                                                     preferences: preferredColors)

        return colorScheme
    }

    // MARK: - Private Implementation

    private func setupModels() {
        Logger.shared.info("Setting up design AI models")

        // Load recommendation model
        loadModel(named: MLConstants.designRecommendationModel) { [weak self] result in
            switch result {
            case .success(let model):
                self?.recommendationModel = model
                self?.isInitialized = true
                Logger.shared.info("Design AI model loaded successfully")
            case .failure(let error):
                Logger.shared.error("Failed to load design AI model", error: error, category: .general)
            }
        }
    }

    private func loadModel(named modelName: String, completion: @escaping (Result<VNCoreMLModel, DesignAIError>) -> Void) {
        modelQueue.async {
            do {
                guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
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

    private func performRecommendationGeneration(request: DesignRecommendationRequest,
                                               completion: @escaping (Result<DesignRecommendation, DesignAIError>) -> Void) {

        _ = Date()
        recommendationProgress.send(0.1)

        // Analyze current room state
        let roomAnalysis = analyzeCurrentRoomState(request)
        recommendationProgress.send(0.3)

        // Generate furniture suggestions
        let furnitureSuggestions = generateFurnitureSuggestions(request: request, analysis: roomAnalysis)
        recommendationProgress.send(0.6)

        // Generate layout improvements
        let layoutImprovements = generateLayoutImprovements(request: request, analysis: roomAnalysis)
        recommendationProgress.send(0.8)

        // Generate color scheme if needed
        let colorScheme = request.detectedFurniture.isEmpty ? nil :
            generateColorScheme(for: request.detectedFurniture, preferences: request.userPreferences)

        // Calculate overall confidence
        let confidence = calculateRecommendationConfidence(suggestions: furnitureSuggestions,
                                                        improvements: layoutImprovements)

        // Create recommendation
        let recommendation = DesignRecommendation(
            title: generateRecommendationTitle(request: request),
            description: generateRecommendationDescription(request: request, analysis: roomAnalysis),
            suggestions: furnitureSuggestions,
            layoutImprovements: layoutImprovements,
            colorScheme: colorScheme,
            confidence: confidence,
            reasoning: generateRecommendationReasoning(request: request, analysis: roomAnalysis)
        )

        recommendationProgress.send(1.0)
        completion(.success(recommendation))
    }

    private func analyzeCurrentRoomState(_ request: DesignRecommendationRequest) -> RoomAnalysis {
        // Analyze room dimensions from point cloud
        let roomDimensions = request.pointCloud.map { estimateRoomDimensions(from: $0) }

        // Analyze furniture distribution
        let furnitureClusters = clusterFurniture(request.detectedFurniture)

        // Analyze space utilization
        let spaceUtilization = calculateSpaceUtilization(pointCloud: request.pointCloud,
                                                       furniture: request.detectedFurniture)

        return RoomAnalysis(
            estimatedDimensions: roomDimensions,
            furnitureClusters: furnitureClusters,
            spaceUtilization: spaceUtilization,
            dominantStyles: extractDominantStyles(from: request.detectedFurniture)
        )
    }

    private func generateFurnitureSuggestions(request: DesignRecommendationRequest,
                                            analysis: RoomAnalysis) -> [FurnitureSuggestion] {

        var suggestions: [FurnitureSuggestion] = []

        // Suggest missing essential furniture
        let missingEssentials = identifyMissingEssentialFurniture(
            existing: request.detectedFurniture,
            roomPurpose: request.userPreferences?.roomPurpose ?? .mixed
        )

        for essential in missingEssentials {
            let position = findOptimalPosition(for: essential, in: request)
            suggestions.append(FurnitureSuggestion(
                category: essential,
                position: position,
                reason: generatePlacementReason(for: essential, analysis: analysis),
                confidence: 0.8
            ))
        }

        // Suggest complementary furniture
        let complementary = identifyComplementaryFurniture(
            existing: request.detectedFurniture,
            preferences: request.userPreferences
        )

        for item in complementary {
            let position = findOptimalPosition(for: item, in: request)
            suggestions.append(FurnitureSuggestion(
                category: item,
                position: position,
                reason: generateComplementaryReason(for: item, existing: request.detectedFurniture),
                confidence: 0.6
            ))
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    private func generateLayoutImprovements(request: DesignRecommendationRequest,
                                          analysis: RoomAnalysis) -> [LayoutImprovement] {

        var improvements: [LayoutImprovement] = []

        // Spacing improvements
        let spacingIssues = analyzeFurnitureSpacing(request.existingFurniture)
        for issue in spacingIssues {
            improvements.append(LayoutImprovement(
                type: .spacing,
                description: issue.description,
                affectedArea: issue.position,
                improvement: "Consider rearranging furniture to create \(issue.recommendedSpacing)m of clearance"
            ))
        }

        // Traffic flow improvements
        let trafficIssues = analyzeTrafficFlow(request.existingFurniture)
        for issue in trafficIssues {
            improvements.append(LayoutImprovement(
                type: .trafficFlow,
                description: issue.description,
                affectedArea: issue.position,
                improvement: issue.suggestion
            ))
        }

        // Balance improvements
        if analysis.spaceUtilization < 0.6 {
            improvements.append(LayoutImprovement(
                type: .balance,
                description: "Room appears under-furnished",
                affectedArea: SIMD3<Float>(0, 0, 0),
                improvement: "Consider adding more furniture to create a balanced, lived-in feel"
            ))
        }

        return improvements
    }

    // MARK: - Helper Methods

    private func estimateRoomDimensions(from pointCloud: PointCloud) -> RoomDimensions {
        let bounds = pointCloud.bounds
        return RoomDimensions(
            width: bounds.size.x,
            height: bounds.size.y,
            depth: bounds.size.z
        )
    }

    private func clusterFurniture(_ furniture: [DetectedFurniture]) -> [FurnitureCluster] {
        // Simple clustering based on proximity (placeholder implementation)
        return furniture.map { FurnitureCluster(furniture: [$0], center: SIMD3<Float>(0, 0, 0), size: SIMD3<Float>(1, 1, 1)) }
    }

    private func calculateSpaceUtilization(pointCloud: PointCloud?, furniture: [DetectedFurniture]) -> Float {
        guard let pointCloud = pointCloud else { return 0.5 }

        let roomVolume = pointCloud.bounds.volume
        let furnitureVolume = furniture.reduce(0) { $0 + $1.estimatedDimensions.0 * $1.estimatedDimensions.1 * $1.estimatedDimensions.2 }

        return min(furnitureVolume / (roomVolume * 0.1), 1.0) // Assume 10% utilization is "full"
    }

    private func extractDominantStyles(from furniture: [DetectedFurniture]) -> [FurnitureStyle] {
        // Placeholder - would analyze detected furniture styles
        return [.modern, .contemporary]
    }

    private func identifyMissingEssentialFurniture(existing: [DetectedFurniture], roomPurpose: UserDesignPreferences.RoomPurpose) -> [FurnitureCategory] {
        let existingCategories = Set(existing.map { $0.category })

        switch roomPurpose {
        case .living:
            return [.sofa, .chair, .table].filter { !existingCategories.contains($0) }
        case .bedroom:
            return [.bed, .cabinet].filter { !existingCategories.contains($0) }
        case .dining:
            return [.table, .chair].filter { !existingCategories.contains($0) }
        case .office:
            return [.desk, .chair].filter { !existingCategories.contains($0) }
        case .mixed:
            return [.sofa, .table, .chair].filter { !existingCategories.contains($0) }
        }
    }

    private func identifyComplementaryFurniture(existing: [DetectedFurniture], preferences: UserDesignPreferences?) -> [FurnitureCategory] {
        // Suggest complementary items based on existing furniture and preferences
        let existingCategories = Set(existing.map { $0.category })

        if existingCategories.contains(.sofa) && !existingCategories.contains(.table) {
            return [.table, .lamp]
        }

        if existingCategories.contains(.bed) && !existingCategories.contains(.cabinet) {
            return [.cabinet, .lamp]
        }

        return [.decorative, .lamp]
    }

    private func findOptimalPosition(for category: FurnitureCategory, in request: DesignRecommendationRequest) -> SIMD3<Float> {
        // Simple positioning logic - place items at reasonable distances from walls
        guard let dimensions = request.roomDimensions else {
            return SIMD3<Float>(2, 0, 2) // Default position
        }

        switch category {
        case .sofa:
            return SIMD3<Float>(dimensions.depth * 0.8, 0, dimensions.width * 0.5)
        case .table:
            return SIMD3<Float>(dimensions.depth * 0.6, 0, dimensions.width * 0.5)
        case .bed:
            return SIMD3<Float>(dimensions.depth * 0.8, 0, dimensions.width * 0.8)
        case .desk:
            return SIMD3<Float>(dimensions.depth * 0.3, 0, dimensions.width * 0.3)
        default:
            return SIMD3<Float>(dimensions.depth * 0.5, 0, dimensions.width * 0.5)
        }
    }

    private func generatePlacementReason(for category: FurnitureCategory, analysis: RoomAnalysis) -> String {
        switch category {
        case .sofa:
            return "Primary seating area creates focal point and encourages social interaction"
        case .table:
            return "Surface area for activities and display of decorative items"
        case .bed:
            return "Rest area positioned for privacy and comfort"
        case .desk:
            return "Workspace positioned for natural light and productivity"
        default:
            return "Complementary piece enhances room functionality and aesthetics"
        }
    }

    private func generateComplementaryReason(for category: FurnitureCategory, existing: [DetectedFurniture]) -> String {
        return "Complements existing \(existing.first?.category.displayName ?? "furniture") for better room balance"
    }

    private func calculateRecommendationConfidence(suggestions: [FurnitureSuggestion], improvements: [LayoutImprovement]) -> Float {
        let suggestionConfidence = suggestions.isEmpty ? 0 : suggestions.reduce(0) { $0 + $1.confidence } / Float(suggestions.count)
        let improvementScore = min(Float(improvements.count) * 0.1 + 0.5, 1.0)
        return (suggestionConfidence + improvementScore) / 2.0
    }

    private func generateRecommendationTitle(request: DesignRecommendationRequest) -> String {
        // RoomPurpose isn't RawRepresentable; use a display name if available elsewhere, otherwise map here
        let roomPurposeName: String
        switch request.userPreferences?.roomPurpose {
        case .some(.living): roomPurposeName = "Living"
        case .some(.bedroom): roomPurposeName = "Bedroom"
        case .some(.dining): roomPurposeName = "Dining"
        case .some(.office): roomPurposeName = "Office"
        case .some(.mixed): roomPurposeName = "Room"
        case .none: roomPurposeName = "Room"
        }

        let itemCount = request.detectedFurniture.count
        return "\(roomPurposeName) Design Recommendations (\(itemCount) items detected)"
    }

    private func generateRecommendationDescription(request: DesignRecommendationRequest, analysis: RoomAnalysis) -> String {
        var description = "Based on analysis of your space"

        if let dimensions = analysis.estimatedDimensions {
            description += " measuring approximately \(String(format: "%.1f", dimensions.width))m x \(String(format: "%.1f", dimensions.depth))m"
        }

        description += ", here are personalized recommendations to enhance your room's functionality and aesthetics."

        return description
    }

    private func generateRecommendationReasoning(request: DesignRecommendationRequest, analysis: RoomAnalysis) -> String {
        var reasoning = "Analysis considered"

        if let pointCloud = request.pointCloud {
            reasoning += " spatial data (\(pointCloud.pointCount) points)"
        }

        reasoning += " and \(request.detectedFurniture.count) detected furniture items"

        if let preferences = request.userPreferences {
            reasoning += " with \(preferences.style.displayName) style preferences"
        }

        reasoning += " to generate balanced, functional recommendations."

        return reasoning
    }

    // MARK: - Layout Analysis Helpers

    private func analyzeFurnitureSpacing(_ furniture: [FurniturePlacementContext]) -> [SpacingIssue] {
        // Analyze spacing between furniture items
        var issues: [SpacingIssue] = []

        for i in 0..<furniture.count {
            for j in i+1..<furniture.count {
                let distance = distanceBetween(furniture[i].position, furniture[j].position)
                let recommendedSpacing = recommendedSpacingBetween(furniture[i].furniture.category, furniture[j].furniture.category)

                if distance < recommendedSpacing * 0.8 { // Less than 80% of recommended
                    issues.append(SpacingIssue(
                        position: (furniture[i].position + furniture[j].position) * 0.5,
                        description: "Tight spacing between \(furniture[i].furniture.category.displayName) and \(furniture[j].furniture.category.displayName)",
                        currentSpacing: distance,
                        recommendedSpacing: recommendedSpacing
                    ))
                }
            }
        }

        return issues
    }

    private func analyzeTrafficFlow(_ furniture: [FurniturePlacementContext]) -> [TrafficFlowIssue] {
        // Analyze potential traffic flow obstructions
        var issues: [TrafficFlowIssue] = []

        // Check for blocked pathways (simplified logic)
        let pathways = identifyPotentialPathways(furniture)

        for pathway in pathways {
            let obstructions = furniture.filter { isObstructing(pathway, furniture: $0) }

            if !obstructions.isEmpty {
                issues.append(TrafficFlowIssue(
                    position: pathway.center,
                    description: "Pathway may be obstructed by \(obstructions.count) furniture item(s)",
                    suggestion: "Consider rearranging furniture to maintain clear pathways of at least 0.9m width"
                ))
            }
        }

        return issues
    }

    private func analyzeRoomBalance(_ furniture: [FurniturePlacementContext]) -> BalanceAnalysis {
        // Analyze visual balance and focal points
        let center = calculateRoomCenter(furniture)
        let balanceScore = calculateBalanceScore(furniture, center: center)

        return BalanceAnalysis(
            center: center,
            balanceScore: balanceScore,
            focalPoints: identifyFocalPoints(furniture),
            symmetryScore: calculateSymmetryScore(furniture)
        )
    }

    private func calculateOverallLayoutScore(spacingIssues: Int, trafficIssues: Int, balanceScore: Float) -> Float {
        let spacingPenalty = min(Float(spacingIssues) * 0.1, 0.3)
        let trafficPenalty = min(Float(trafficIssues) * 0.15, 0.4)
        let balanceBonus = balanceScore * 0.3

        return max(min(1.0 - spacingPenalty - trafficPenalty + balanceBonus, 1.0), 0.0)
    }

    private func generateLayoutRecommendations(spacingIssues: [SpacingIssue],
                                            trafficIssues: [TrafficFlowIssue],
                                            balanceAnalysis: BalanceAnalysis) -> [String] {

        var recommendations: [String] = []

        if !spacingIssues.isEmpty {
            recommendations.append("Increase spacing between furniture items for better flow and accessibility")
        }

        if !trafficIssues.isEmpty {
            recommendations.append("Ensure clear pathways of at least 0.9m for comfortable movement")
        }

        if balanceAnalysis.balanceScore < 0.6 {
            recommendations.append("Consider adding visual weight to balance the room composition")
        }

        if balanceAnalysis.symmetryScore < 0.5 {
            recommendations.append("Experiment with symmetrical arrangements for a more formal feel")
        }

        return recommendations
    }

    // MARK: - Color Analysis Helpers

    private func extractExistingColors(from furniture: [DetectedFurniture]) -> Set<FurnitureColor> {
        // Extract colors from detected furniture metadata or image analysis
        return furniture.compactMap { $0.color }.reduce(into: Set<FurnitureColor>()) { $0.insert($1) }
    }

    private func createHarmoniousColorScheme(existingColors: Set<FurnitureColor>, preferences: Set<FurnitureColor>) -> ColorScheme {
        // Generate harmonious color scheme based on existing colors and preferences

        // Default neutral scheme
        let primary = SIMD3<Float>(0.9, 0.9, 0.9) // Light gray
        let secondary = SIMD3<Float>(0.7, 0.7, 0.7) // Medium gray
        let accent = SIMD3<Float>(0.2, 0.4, 0.8) // Blue accent
        let walls = SIMD3<Float>(0.95, 0.95, 0.95) // Off-white
        let flooring = SIMD3<Float>(0.8, 0.8, 0.8) // Light gray

        let reasoning = "Neutral color scheme provides versatile backdrop for various furniture styles and personal preferences"

        return ColorScheme(
            primaryColor: primary,
            secondaryColor: secondary,
            accentColor: accent,
            wallColor: walls,
            flooringColor: flooring,
            reasoning: reasoning
        )
    }

    // MARK: - Utility Functions

    private func distanceBetween(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return length(a - b)
    }

    private func recommendedSpacingBetween(_ category1: FurnitureCategory, _ category2: FurnitureCategory) -> Float {
        // Return recommended spacing in meters
        return 1.0 // Default 1 meter spacing
    }

    private func identifyPotentialPathways(_ furniture: [FurniturePlacementContext]) -> [Pathway] {
        // Identify potential walking paths in the room (placeholder)
        return [Pathway(center: SIMD3<Float>(2, 0, 1.5), width: 0.9)]
    }

    private func isObstructing(_ pathway: Pathway, furniture: FurniturePlacementContext) -> Bool {
        let distance = distanceBetween(pathway.center, furniture.position)
        return distance < pathway.width / 2
    }

    private func calculateRoomCenter(_ furniture: [FurniturePlacementContext]) -> SIMD3<Float> {
        guard !furniture.isEmpty else { return SIMD3<Float>(0, 0, 0) }

        let sum = furniture.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.position }
        return sum / Float(furniture.count)
    }

    private func calculateBalanceScore(_ furniture: [FurniturePlacementContext], center: SIMD3<Float>) -> Float {
        // Calculate how evenly distributed furniture is around the center
        let distances = furniture.map { distanceBetween($0.position, center) }
        let avgDistance = distances.reduce(0, +) / Float(distances.count)
        let variance = distances.reduce(0) { $0 + pow($1 - avgDistance, 2) } / Float(distances.count)

        return 1.0 / (1.0 + variance) // Lower variance = higher balance score
    }

    private func identifyFocalPoints(_ furniture: [FurniturePlacementContext]) -> [SIMD3<Float>] {
        // Identify potential focal points (largest or most prominent furniture)
        return furniture
            .sorted { $0.furniture.category.typicalDimensions.0 > $1.furniture.category.typicalDimensions.0 }
            .prefix(3)
            .map { $0.position }
    }

    private func calculateSymmetryScore(_ furniture: [FurniturePlacementContext]) -> Float {
        // Calculate symmetry score (simplified)
        guard furniture.count >= 2 else { return 0.5 }

        // Check if furniture is arranged symmetrically
        let center = calculateRoomCenter(furniture)
        var symmetryPairs = 0
        var totalPairs = 0

        for i in 0..<furniture.count {
            for j in i+1..<furniture.count {
                let pos1 = furniture[i].position
                let pos2 = furniture[j].position

                // Check if positions are roughly mirrored across center
                let mirrored1 = SIMD3<Float>(2 * center.x - pos1.x, pos1.y, pos1.z)
                let distanceToMirror = distanceBetween(pos2, mirrored1)

                totalPairs += 1
                if distanceToMirror < 0.5 { // Within 50cm
                    symmetryPairs += 1
                }
            }
        }

        return totalPairs > 0 ? Float(symmetryPairs) / Float(totalPairs) : 0.5
    }
}

// MARK: - Supporting Types

/// Room analysis result
public struct RoomAnalysis {
    public let estimatedDimensions: RoomDimensions?
    public let furnitureClusters: [FurnitureCluster]
    public let spaceUtilization: Float
    public let dominantStyles: [FurnitureStyle]
}

/// Furniture cluster
public struct FurnitureCluster {
    public let furniture: [DetectedFurniture]
    public let center: SIMD3<Float>
    public let size: SIMD3<Float>
}

/// Spacing issue
public struct SpacingIssue {
    public let position: SIMD3<Float>
    public let description: String
    public let currentSpacing: Float
    public let recommendedSpacing: Float
}

/// Traffic flow issue
public struct TrafficFlowIssue {
    public let position: SIMD3<Float>
    public let description: String
    public let suggestion: String
}

/// Balance analysis
public struct BalanceAnalysis {
    public let center: SIMD3<Float>
    public let balanceScore: Float
    public let focalPoints: [SIMD3<Float>]
    public let symmetryScore: Float
}

/// Room layout analysis
public struct RoomLayoutAnalysis {
    public let spacingIssues: [SpacingIssue]
    public let trafficFlowIssues: [TrafficFlowIssue]
    public let balanceAnalysis: BalanceAnalysis
    public let overallScore: Float
    public let recommendations: [String]
}

/// Pathway in room
public struct Pathway {
    public let center: SIMD3<Float>
    public let width: Float
}

/// Design AI errors
public enum DesignAIError: LocalizedError {
    case serviceUnavailable
    case modelNotFound(String)
    case modelLoadingFailed(String)
    case invalidInput(String)
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Design AI service is currently unavailable"
        case .modelNotFound(let modelName):
            return "Required model '\(modelName)' not found"
        case .modelLoadingFailed(let reason):
            return "Failed to load AI model: \(reason)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .processingFailed(let reason):
            return "AI processing failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .serviceUnavailable:
            return "Please try again later"
        case .modelNotFound, .modelLoadingFailed:
            return "Please reinstall the app to restore AI models"
        case .invalidInput:
            return "Please check your input and try again"
        case .processingFailed:
            return "Please try again with different parameters"
        }
    }
}

