//
//  DetectionError.swift
//  InteriorAI
//
//  Custom error types for furniture detection operations
//

import Foundation

/// Custom error types for furniture detection operations
public enum DetectionError: LocalizedError, Equatable {
    // MARK: - Model Errors
    case modelNotFound(String)
    case modelLoadingFailed(String)
    case modelVersionMismatch(String, String)
    case modelCorrupted

    // MARK: - Input Validation Errors
    case invalidImageData
    case imageTooSmall(CGSize, CGSize)
    case imageTooLarge(CGSize, CGSize)
    case unsupportedImageFormat(String)
    case imageProcessingFailed(String)

    // MARK: - Detection Errors
    case noObjectsDetected
    case detectionFailed(String)
    case confidenceTooLow(Float, Float)
    case multipleObjectsDetected(Int)
    case objectOutOfBounds

    // MARK: - Classification Errors
    case classificationFailed(String)
    case unknownFurnitureType(String)
    case ambiguousClassification([String])

    // MARK: - Processing Errors
    case processingTimeout(TimeInterval)
    case insufficientComputeResources
    case memoryAllocationFailed(Int64)

    // MARK: - Data Validation Errors
    case invalidDetectionResult(String)
    case corruptedDetectionData
    case incompatibleDataFormat(String)

    // MARK: - Storage Errors
    case detectionSaveFailed(String)
    case detectionLoadFailed(String)
    case cacheQuotaExceeded(Int64)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelName):
            return "Required model '\(modelName)' not found. Please ensure all models are properly installed."
        case .modelLoadingFailed(let reason):
            return "Failed to load detection model: \(reason)"
        case .modelVersionMismatch(let expected, let actual):
            return "Model version mismatch. Expected: \(expected), Found: \(actual). Please update the model."
        case .modelCorrupted:
            return "Detection model appears to be corrupted. Please reinstall the model."

        case .invalidImageData:
            return "Invalid image data provided for detection."
        case .imageTooSmall(let actual, let minimum):
            return "Image too small (\(Int(actual.width))x\(Int(actual.height))). Minimum size: \(Int(minimum.width))x\(Int(minimum.height))."
        case .imageTooLarge(let actual, let maximum):
            return "Image too large (\(Int(actual.width))x\(Int(actual.height))). Maximum size: \(Int(maximum.width))x\(Int(maximum.height))."
        case .unsupportedImageFormat(let format):
            return "Unsupported image format: \(format). Supported formats: JPEG, PNG."
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"

        case .noObjectsDetected:
            return "No furniture objects detected in the image. Please ensure the furniture is clearly visible."
        case .detectionFailed(let reason):
            return "Object detection failed: \(reason)"
        case .confidenceTooLow(let actual, let minimum):
            return "Detection confidence too low (\(String(format: "%.1f", actual * 100))%). Minimum required: \(String(format: "%.1f", minimum * 100))%."
        case .multipleObjectsDetected(let count):
            return "Multiple objects detected (\(count)). Please focus on a single piece of furniture."
        case .objectOutOfBounds:
            return "Detected object is partially out of frame. Please center the furniture in the image."

        case .classificationFailed(let reason):
            return "Furniture classification failed: \(reason)"
        case .unknownFurnitureType(let type):
            return "Unknown furniture type detected: \(type)"
        case .ambiguousClassification(let types):
            return "Ambiguous classification. Possible types: \(types.joined(separator: ", "))"

        case .processingTimeout(let duration):
            return "Detection processing timed out after \(Int(duration)) seconds."
        case .insufficientComputeResources:
            return "Insufficient compute resources available for detection."
        case .memoryAllocationFailed(let bytes):
            return "Failed to allocate \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)) of memory."

        case .invalidDetectionResult(let reason):
            return "Invalid detection result: \(reason)"
        case .corruptedDetectionData:
            return "Detection data appears to be corrupted."
        case .incompatibleDataFormat(let format):
            return "Incompatible data format: \(format)"

        case .detectionSaveFailed(let reason):
            return "Failed to save detection result: \(reason)"
        case .detectionLoadFailed(let reason):
            return "Failed to load detection result: \(reason)"
        case .cacheQuotaExceeded(let size):
            return "Detection cache quota exceeded (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))). Please clear cache."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotFound, .modelCorrupted:
            return "Please reinstall the app to restore the required models."
        case .modelVersionMismatch:
            return "Please update to the latest version of the app."
        case .modelLoadingFailed:
            return "Try restarting the app. If the problem persists, reinstall the app."

        case .invalidImageData, .unsupportedImageFormat:
            return "Please use a valid JPEG or PNG image file."
        case .imageTooSmall:
            return "Take the photo from closer to the furniture or use zoom."
        case .imageTooLarge:
            return "Reduce image size or use a lower resolution camera setting."
        case .imageProcessingFailed:
            return "Try taking a new photo with better lighting conditions."

        case .noObjectsDetected:
            return "Ensure the furniture is well-lit and clearly visible in the photo. Remove any obstructions."
        case .confidenceTooLow:
            return "Improve lighting, reduce camera shake, or take the photo from a different angle."
        case .multipleObjectsDetected:
            return "Focus the camera on a single piece of furniture for better results."
        case .objectOutOfBounds:
            return "Center the furniture in the frame and ensure it fits completely within the image."

        case .classificationFailed, .ambiguousClassification:
            return "Try taking a clearer photo or photographing the furniture from a different angle."
        case .unknownFurnitureType:
            return "This type of furniture may not be supported yet. Please contact support for assistance."

        case .processingTimeout:
            return "Try using a device with better performance or reduce image complexity."
        case .insufficientComputeResources, .memoryAllocationFailed:
            return "Close other apps and try again. If the problem persists, restart your device."

        case .corruptedDetectionData, .invalidDetectionResult:
            return "Try running the detection again with a new image."

        case .cacheQuotaExceeded:
            return "Clear the app cache in Settings to free up space."

        default:
            return "Please try again. If the problem persists, contact support."
        }
    }

    // MARK: - Equatable Conformance
    public static func == (lhs: DetectionError, rhs: DetectionError) -> Bool {
        switch (lhs, rhs) {
        case (.modelNotFound(let lhsModel), .modelNotFound(let rhsModel)):
            return lhsModel == rhsModel
        case (.modelVersionMismatch(let lhsExpected, let lhsActual), .modelVersionMismatch(let rhsExpected, let rhsActual)):
            return lhsExpected == rhsExpected && lhsActual == rhsActual
        case (.imageTooSmall(let lhsActual, let lhsMin), .imageTooSmall(let rhsActual, let rhsMin)):
            return lhsActual == rhsActual && lhsMin == rhsMin
        case (.imageTooLarge(let lhsActual, let lhsMax), .imageTooLarge(let rhsActual, let rhsMax)):
            return lhsActual == rhsActual && lhsMax == rhsMax
        case (.confidenceTooLow(let lhsActual, let lhsMin), .confidenceTooLow(let rhsActual, let rhsMin)):
            return lhsActual == rhsActual && lhsMin == rhsMin
        case (.multipleObjectsDetected(let lhsCount), .multipleObjectsDetected(let rhsCount)):
            return lhsCount == rhsCount
        case (.processingTimeout(let lhsDuration), .processingTimeout(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.memoryAllocationFailed(let lhsBytes), .memoryAllocationFailed(let rhsBytes)):
            return lhsBytes == rhsBytes
        case (.cacheQuotaExceeded(let lhsSize), .cacheQuotaExceeded(let rhsSize)):
            return lhsSize == rhsSize

        case (.modelCorrupted, .modelCorrupted),
             (.invalidImageData, .invalidImageData),
             (.noObjectsDetected, .noObjectsDetected),
             (.objectOutOfBounds, .objectOutOfBounds),
             (.corruptedDetectionData, .corruptedDetectionData),
             (.insufficientComputeResources, .insufficientComputeResources):
            return true

        case (.modelLoadingFailed(let lhsReason), .modelLoadingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.unsupportedImageFormat(let lhsFormat), .unsupportedImageFormat(let rhsFormat)):
            return lhsFormat == rhsFormat
        case (.imageProcessingFailed(let lhsReason), .imageProcessingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.detectionFailed(let lhsReason), .detectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.classificationFailed(let lhsReason), .classificationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.unknownFurnitureType(let lhsType), .unknownFurnitureType(let rhsType)):
            return lhsType == rhsType
        case (.invalidDetectionResult(let lhsReason), .invalidDetectionResult(let rhsReason)):
            return lhsReason == rhsReason
        case (.incompatibleDataFormat(let lhsFormat), .incompatibleDataFormat(let rhsFormat)):
            return lhsFormat == rhsFormat
        case (.detectionSaveFailed(let lhsReason), .detectionSaveFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.detectionLoadFailed(let lhsReason), .detectionLoadFailed(let rhsReason)):
            return lhsReason == rhsReason

        case (.ambiguousClassification(let lhsTypes), .ambiguousClassification(let rhsTypes)):
            return lhsTypes == rhsTypes

        default:
            return false
        }
    }
}
