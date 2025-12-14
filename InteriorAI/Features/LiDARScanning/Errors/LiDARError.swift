//
//  LiDARError.swift
//  InteriorAI
//
//  Custom error types for LiDAR scanning operations
//

import Foundation

/// Custom error types for LiDAR scanning operations
public enum LiDARError: LocalizedError, Equatable {
    // MARK: - Device Compatibility Errors
    case deviceNotSupported(String)
    case liDARUnavailable
    case cameraAccessDenied
    case cameraAccessRestricted

    // MARK: - Scanning Errors
    case scanInitializationFailed(String)
    case scanTimeoutExceeded(TimeInterval)
    case insufficientLighting
    case excessiveMovement
    case surfaceTooDark
    case surfaceTooReflective

    // MARK: - Data Processing Errors
    case pointCloudGenerationFailed(String)
    case meshReconstructionFailed(String)
    case dataCorruptionDetected
    case insufficientDataPoints(Int)

    // MARK: - Storage Errors
    case scanSaveFailed(String)
    case scanLoadFailed(String)
    case storageQuotaExceeded(Int64)

    // MARK: - Session Errors
    case sessionInterrupted(String)
    case sessionConfigurationInvalid(String)
    case arSessionFailed(String)

    // MARK: - Validation Errors
    case invalidScanParameters(String)
    case scanQualityTooLow(Float)
    case scanIncomplete

    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let device):
            return "Device '\(device)' does not support LiDAR scanning. Please use an iPhone 12 Pro or newer."
        case .liDARUnavailable:
            return "LiDAR scanner is currently unavailable. Please try again."
        case .cameraAccessDenied:
            return "Camera access is required for LiDAR scanning. Please enable camera permissions in Settings."
        case .cameraAccessRestricted:
            return "Camera access is restricted. Please check parental controls or device restrictions."

        case .scanInitializationFailed(let reason):
            return "Failed to initialize scan: \(reason)"
        case .scanTimeoutExceeded(let duration):
            return "Scan timed out after \(Int(duration)) seconds. Please try scanning in a well-lit area."
        case .insufficientLighting:
            return "Insufficient lighting for accurate scanning. Please ensure the room is well-lit."
        case .excessiveMovement:
            return "Excessive device movement detected. Please hold the device steady during scanning."
        case .surfaceTooDark:
            return "Surface appears too dark for accurate scanning. Please improve lighting conditions."
        case .surfaceTooReflective:
            return "Surface appears too reflective. Please avoid shiny or mirrored surfaces."

        case .pointCloudGenerationFailed(let reason):
            return "Failed to generate point cloud: \(reason)"
        case .meshReconstructionFailed(let reason):
            return "Failed to reconstruct mesh: \(reason)"
        case .dataCorruptionDetected:
            return "Scan data corruption detected. Please restart the scan."
        case .insufficientDataPoints(let points):
            return "Insufficient data points collected (\(points)). Please scan for a longer duration."

        case .scanSaveFailed(let reason):
            return "Failed to save scan: \(reason)"
        case .scanLoadFailed(let reason):
            return "Failed to load scan: \(reason)"
        case .storageQuotaExceeded(let size):
            return "Storage quota exceeded (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))). Please free up space."

        case .sessionInterrupted(let reason):
            return "Scan session was interrupted: \(reason)"
        case .sessionConfigurationInvalid(let reason):
            return "Invalid session configuration: \(reason)"
        case .arSessionFailed(let reason):
            return "AR session failed: \(reason)"

        case .invalidScanParameters(let reason):
            return "Invalid scan parameters: \(reason)"
        case .scanQualityTooLow(let quality):
            return "Scan quality too low (\(String(format: "%.1f", quality * 100))%). Please improve scanning conditions."
        case .scanIncomplete:
            return "Scan is incomplete. Please complete the full scan before proceeding."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deviceNotSupported:
            return "Use an iPhone with LiDAR capabilities (iPhone 12 Pro or newer)."
        case .liDARUnavailable:
            return "Ensure the device is not overheating and try again in a few minutes."
        case .cameraAccessDenied, .cameraAccessRestricted:
            return "Go to Settings > Privacy & Security > Camera and enable access for InteriorAI."

        case .scanTimeoutExceeded, .insufficientLighting, .surfaceTooDark:
            return "Move to a well-lit area and ensure all surfaces are visible and properly illuminated."
        case .excessiveMovement:
            return "Hold the device as steady as possible. Use a tripod if available."
        case .surfaceTooReflective:
            return "Avoid scanning highly reflective surfaces like mirrors or polished metals."

        case .insufficientDataPoints:
            return "Continue scanning for at least 30 seconds to collect sufficient data points."
        case .scanQualityTooLow:
            return "Slow down your scanning motion and ensure consistent lighting throughout the room."

        case .storageQuotaExceeded:
            return "Delete old scans or move them to external storage to free up space."

        case .dataCorruptionDetected, .scanIncomplete:
            return "Restart the scan from the beginning."

        default:
            return "Please try again. If the problem persists, contact support."
        }
    }

    // MARK: - Equatable Conformance
    public static func == (lhs: LiDARError, rhs: LiDARError) -> Bool {
        switch (lhs, rhs) {
        case (.deviceNotSupported(let lhsDevice), .deviceNotSupported(let rhsDevice)):
            return lhsDevice == rhsDevice
        case (.scanTimeoutExceeded(let lhsDuration), .scanTimeoutExceeded(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.insufficientDataPoints(let lhsPoints), .insufficientDataPoints(let rhsPoints)):
            return lhsPoints == rhsPoints
        case (.storageQuotaExceeded(let lhsSize), .storageQuotaExceeded(let rhsSize)):
            return lhsSize == rhsSize
        case (.scanQualityTooLow(let lhsQuality), .scanQualityTooLow(let rhsQuality)):
            return lhsQuality == rhsQuality

        case (.liDARUnavailable, .liDARUnavailable),
             (.cameraAccessDenied, .cameraAccessDenied),
             (.cameraAccessRestricted, .cameraAccessRestricted),
             (.insufficientLighting, .insufficientLighting),
             (.excessiveMovement, .excessiveMovement),
             (.surfaceTooDark, .surfaceTooDark),
             (.surfaceTooReflective, .surfaceTooReflective),
             (.dataCorruptionDetected, .dataCorruptionDetected),
             (.scanIncomplete, .scanIncomplete):
            return true

        case (.scanInitializationFailed(let lhsReason), .scanInitializationFailed(let rhsReason)),
             (.pointCloudGenerationFailed(let lhsReason), .pointCloudGenerationFailed(let rhsReason)),
             (.meshReconstructionFailed(let lhsReason), .meshReconstructionFailed(let rhsReason)),
             (.scanSaveFailed(let lhsReason), .scanSaveFailed(let rhsReason)),
             (.scanLoadFailed(let lhsReason), .scanLoadFailed(let rhsReason)),
             (.sessionInterrupted(let lhsReason), .sessionInterrupted(let rhsReason)),
             (.sessionConfigurationInvalid(let lhsReason), .sessionConfigurationInvalid(let rhsReason)),
             (.arSessionFailed(let lhsReason), .arSessionFailed(let rhsReason)),
             (.invalidScanParameters(let lhsReason), .invalidScanParameters(let rhsReason)):
            return lhsReason == rhsReason

        default:
            return false
        }
    }
}
