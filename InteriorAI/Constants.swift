//
//  Constants.swift
//  InteriorAI
//
//  Constants and configuration values for the InteriorAI application
//

import Foundation

// MARK: - App Information
enum AppConstants {
    static let appName = "InteriorAI"
    static let appVersion = "1.0.0"
    static let appBundleId = "com.interiorai.app"

    static let minimumIOSVersion = "16.0"
    static let targetIOSVersion = "17.0"
}

// MARK: - API Configuration
enum APIConstants {
    static let baseURL = "https://api.interiorai.com"
    static let apiVersion = "v1"

    static let timeoutInterval: TimeInterval = 30.0
    static let retryAttempts = 3
    static let retryDelay: TimeInterval = 2.0
}

// MARK: - ARKit Configuration
enum ARConstants {
    static let minimumLiDARDevices = ["iPhone 12 Pro", "iPhone 12 Pro Max", "iPhone 13 Pro", "iPhone 13 Pro Max", "iPhone 14 Pro", "iPhone 14 Pro Max", "iPhone 15 Pro", "iPhone 15 Pro Max"]

    static let pointCloudQuality: Float = 0.8
    static let meshQuality: Float = 0.7
    static let maxScanDuration: TimeInterval = 300.0 // 5 minutes

    static let confidenceThreshold: Float = 0.6
    static let smoothingFactor: Float = 0.3
}

// MARK: - Core ML Configuration
enum MLConstants {
    static let furnitureDetectionModel = "FurnitureDetector"
    static let designRecommendationModel = "DesignRecommender"
    static let confidenceThreshold: Float = 0.75

    static let maxProcessingBatchSize = 10
    static let modelUpdateInterval: TimeInterval = 86400 // 24 hours
}

// MARK: - Security Configuration
enum SecurityConstants {
    static let keychainServiceName = "com.interiorai.keychain"
    static let encryptionAlgorithm = "AES-256-GCM"

    static let certificatePinningEnabled = true
    static let jailbreakDetectionEnabled = true
    static let biometricAuthenticationEnabled = true
}

// MARK: - Storage Configuration
enum StorageConstants {
    static let maxStorageSize: Int64 = 500 * 1024 * 1024 // 500MB
    static let cleanupThreshold: Double = 0.8 // 80%

    static let scanRetentionDays = 90
    static let contextRetentionDays = 365

    static let databaseName = "InteriorAI.sqlite"
}

// MARK: - UI Configuration
enum UIConstants {
    static let primaryColorHex = "#007AFF"
    static let secondaryColorHex = "#5856D6"
    static let accentColorHex = "#FF9500"

    static let cornerRadius: CGFloat = 12.0
    static let borderWidth: CGFloat = 1.0

    static let animationDuration: TimeInterval = 0.3
    static let longAnimationDuration: TimeInterval = 0.6
}

// MARK: - Networking Configuration
enum NetworkConstants {
    static let maxConcurrentRequests = 4
    static let requestTimeout: TimeInterval = 30.0
    static let resourceTimeout: TimeInterval = 300.0

    static let cacheSize: Int = 50 * 1024 * 1024 // 50MB
    static let cacheAge: TimeInterval = 3600 // 1 hour
}

// MARK: - Logging Configuration
enum LoggingConstants {
    static let maxLogFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    static let maxLogFiles = 5

    static let logLevel: String = "INFO"
    static let enableRemoteLogging = false
}

// MARK: - Vector Database Configuration
enum VectorConstants {
    static let maxVectorDimensions = 512
    static let similarityThreshold: Float = 0.8
    static let maxSearchResults = 50

    static let contextBatchSize = 100
    static let vectorUpdateInterval: TimeInterval = 3600 // 1 hour
}

// MARK: - Error Messages
enum ErrorMessages {
    static let genericError = "An unexpected error occurred. Please try again."
    static let networkError = "Unable to connect to the server. Please check your internet connection."
    static let permissionError = "Permission required to access this feature."
    static let storageError = "Insufficient storage space available."
    static let securityError = "Security validation failed."
}

// MARK: - File Extensions
enum FileExtensions {
    static let pointCloud = "ply"
    static let scanData = "interiorai"
    static let exportData = "json"
    static let logFile = "log"
}

// MARK: - User Defaults Keys
enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let userPreferences = "userPreferences"
    static let lastScanDate = "lastScanDate"
    static let scanCount = "scanCount"
    static let designStyle = "designStyle"
    static let colorPreferences = "colorPreferences"
}

// MARK: - Notification Names
enum NotificationNames {
    static let scanCompleted = "ScanCompletedNotification"
    static let detectionCompleted = "DetectionCompletedNotification"
    static let recommendationReady = "RecommendationReadyNotification"
    static let contextUpdated = "ContextUpdatedNotification"
    static let storageWarning = "StorageWarningNotification"
}
