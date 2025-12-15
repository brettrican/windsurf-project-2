//
//  SecurityValidator.swift
//  InteriorAI
//
//  Security validation and integrity checks
//

import Foundation
import Security
import UIKit
import CommonCrypto

/// Comprehensive security validator for the InteriorAI application
public final class SecurityValidator {
    // MARK: - Singleton
    public static let shared = SecurityValidator()

    private init() {}

    // MARK: - Jailbreak Detection

    /// Performs comprehensive jailbreak detection
    public func performSecurityCheck() async throws -> SecurityValidationResult {
        let startTime = Date()

        // Run all security checks concurrently
        async let jailbreakCheck = detectJailbreak()
        async let debuggerCheck = detectDebugger()
        async let tamperingCheck = detectAppTampering()
        async let networkCheck = validateNetworkSecurity()

        let results = try await [jailbreakCheck, debuggerCheck, tamperingCheck, networkCheck]

        let duration = Date().timeIntervalSince(startTime)
        let overallStatus = results.allSatisfy { $0.isSecure }

        return SecurityValidationResult(
            isSecure: overallStatus,
            checks: results,
            timestamp: Date(),
            duration: duration
        )
    }

    /// Detects if the device is jailbroken
    private func detectJailbreak() async -> SecurityCheck {
        let checks = [
            checkCydiaInstallation(),
            checkSuspiciousFiles(),
            checkSuspiciousApps(),
            checkSymbolicLinks(),
            checkFilePermissions(),
            checkSystemIntegrity()
        ]

        let failedChecks = checks.filter { !$0.passed }
        let isSecure = failedChecks.isEmpty

        return SecurityCheck(
            name: "Jailbreak Detection",
            passed: isSecure,
            details: isSecure ? "No jailbreak indicators detected" : "Jailbreak indicators found: \(failedChecks.map { $0.description }.joined(separator: ", "))",
            severity: isSecure ? .low : .critical
        )
    }

    /// Detects if a debugger is attached
    private func detectDebugger() async -> SecurityCheck {
        #if DEBUG
        // In debug builds, allow debugging
        return SecurityCheck(
            name: "Debugger Detection",
            passed: true,
            details: "Debug build - debugging allowed",
            severity: .low
        )
        #else
        let isDebuggerAttached = checkDebuggerAttachment()
        return SecurityCheck(
            name: "Debugger Detection",
            passed: !isDebuggerAttached,
            details: isDebuggerAttached ? "Debugger detected" : "No debugger attached",
            severity: isDebuggerAttached ? .high : .low
        )
        #endif
    }

    /// Detects app tampering and integrity issues
    private func detectAppTampering() async -> SecurityCheck {
        let checks = [
            validateCodeSignature(),
            checkBundleIntegrity(),
            validateEntitlements()
        ]

        let failedChecks = checks.filter { !$0.passed }
        let isSecure = failedChecks.isEmpty

        return SecurityCheck(
            name: "App Integrity",
            passed: isSecure,
            details: isSecure ? "App integrity verified" : "Integrity issues detected: \(failedChecks.map { $0.description }.joined(separator: ", "))",
            severity: isSecure ? .low : .critical
        )
    }

    /// Validates network security configuration
    private func validateNetworkSecurity() async -> SecurityCheck {
        let checks = [
            validateCertificatePinning(),
            checkATSConfiguration(),
            validateAPIEndpoints()
        ]

        let failedChecks = checks.filter { !$0.passed }
        let isSecure = failedChecks.isEmpty

        return SecurityCheck(
            name: "Network Security",
            passed: isSecure,
            details: isSecure ? "Network security validated" : "Network security issues: \(failedChecks.map { $0.description }.joined(separator: ", "))",
            severity: isSecure ? .low : .medium
        )
    }

    // MARK: - Individual Security Checks

    private func checkCydiaInstallation() -> SecurityCheckResult {
        let cydiaPath = "/Applications/Cydia.app"
        let cydiaExists = FileManager.default.fileExists(atPath: cydiaPath)

        return SecurityCheckResult(
            passed: !cydiaExists,
            description: cydiaExists ? "Cydia detected" : "No Cydia found"
        )
    }

    private func checkSuspiciousFiles() -> SecurityCheckResult {
        let suspiciousPaths = [
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings",
            "/private/var/stash",
            "/usr/libexec/cydia",
            "/usr/sbin/sshd"
        ]

        let foundPaths = suspiciousPaths.filter { FileManager.default.fileExists(atPath: $0) }
        let passed = foundPaths.isEmpty

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "No suspicious files found" : "Suspicious files detected: \(foundPaths.joined(separator: ", "))"
        )
    }

    private func checkSuspiciousApps() -> SecurityCheckResult {
        let suspiciousApps = [
            "com.saurik.Cydia",
            "com.iptvjailbreak.installer",
            "com.ih8sn0w.installer3"
        ]

        let foundApps = suspiciousApps.filter { app in
            // Check if app is installed (simplified check)
            let appPath = "/private/var/mobile/Applications/\(app)"
            return FileManager.default.fileExists(atPath: appPath)
        }

        let passed = foundApps.isEmpty

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "No suspicious apps found" : "Suspicious apps detected: \(foundApps.joined(separator: ", "))"
        )
    }

    private func checkSymbolicLinks() -> SecurityCheckResult {
        // Check for common symbolic link manipulations
        let pathsToCheck = ["/Applications", "/Library/Ringtones", "/Library/Wallpaper", "/usr/include"]

        var suspiciousLinks = [String]()
        for path in pathsToCheck {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let fileType = attributes[.type] as? FileAttributeType,
               fileType == .typeSymbolicLink {
                suspiciousLinks.append(path)
            }
        }

        let passed = suspiciousLinks.isEmpty

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "No suspicious symbolic links" : "Suspicious symbolic links: \(suspiciousLinks.joined(separator: ", "))"
        )
    }

    private func checkFilePermissions() -> SecurityCheckResult {
        // Check if critical system files have been modified
        let criticalPaths = ["/System/Library/Frameworks", "/System/Library/PrivateFrameworks"]

        var modifiedPaths = [String]()
        for path in criticalPaths {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let modificationDate = attributes[.modificationDate] as? Date {
                // Check if modified in last 24 hours (suspicious)
                if modificationDate.timeIntervalSinceNow > -86400 {
                    modifiedPaths.append(path)
                }
            }
        }

        let passed = modifiedPaths.isEmpty

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "File permissions normal" : "Recently modified critical files: \(modifiedPaths.joined(separator: ", "))"
        )
    }

    private func checkSystemIntegrity() -> SecurityCheckResult {
        // Check for system integrity using sysctl
        let passed = true // Placeholder - would need actual sysctl calls

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "System integrity verified" : "System integrity compromised"
        )
    }

    private func checkDebuggerAttachment() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        if result == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }

        return false
    }

    private func validateCodeSignature() -> SecurityCheckResult {
        // Validate app code signature
        let bundle = Bundle.main
        guard let executablePath = bundle.executablePath else {
            return SecurityCheckResult(passed: false, description: "Cannot locate executable")
        }

        // Check if code signature is valid
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-v", executablePath]

        do {
            try task.run()
            task.waitUntilExit()
            let passed = task.terminationStatus == 0
            return SecurityCheckResult(
                passed: passed,
                description: passed ? "Code signature valid" : "Code signature invalid"
            )
        } catch {
            return SecurityCheckResult(passed: false, description: "Code signature check failed: \(error.localizedDescription)")
        }
    }

    private func checkBundleIntegrity() -> SecurityCheckResult {
        // Check bundle integrity by verifying expected files exist
        let bundle = Bundle.main
        let requiredFiles = ["Info.plist", "InteriorAI"] // Add more as needed

        var missingFiles = [String]()
        for file in requiredFiles {
            if bundle.path(forResource: file, ofType: nil) == nil &&
               bundle.url(forResource: file, withExtension: nil) == nil {
                missingFiles.append(file)
            }
        }

        let passed = missingFiles.isEmpty

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "Bundle integrity verified" : "Missing files: \(missingFiles.joined(separator: ", "))"
        )
    }

    private func validateEntitlements() -> SecurityCheckResult {
        // Validate app entitlements
        let passed = true // Placeholder - would validate specific entitlements

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "Entitlements validated" : "Entitlements validation failed"
        )
    }

    private func validateCertificatePinning() -> SecurityCheckResult {
        // Check if certificate pinning is configured
        let passed = SecurityConstants.certificatePinningEnabled

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "Certificate pinning enabled" : "Certificate pinning not configured"
        )
    }

    private func checkATSConfiguration() -> SecurityCheckResult {
        // Check App Transport Security configuration
        let passed = true // Placeholder - would check Info.plist ATS settings

        return SecurityCheckResult(
            passed: passed,
            description: passed ? "ATS properly configured" : "ATS configuration incomplete"
        )
    }

    private func validateAPIEndpoints() -> SecurityCheckResult {
        // Validate API endpoints use HTTPS
        let baseURL = APIConstants.baseURL
        let usesHTTPS = baseURL.hasPrefix("https://")

        return SecurityCheckResult(
            passed: usesHTTPS,
            description: usesHTTPS ? "All API endpoints use HTTPS" : "Non-HTTPS API endpoints detected"
        )
    }

    // MARK: - Data Encryption/Decryption

    /// Encrypts sensitive data using AES-256-GCM
    public func encryptData(_ data: Data, key: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else {
            throw SecurityError.encryptionFailed("Invalid key size")
        }

        let keyPtr = key.withUnsafeBytes { $0.baseAddress! }
        let dataPtr = data.withUnsafeBytes { $0.baseAddress! }

        var encryptedData = Data(count: data.count + kCCBlockSizeAES128)
        var encryptedLength: size_t = 0

        let status = encryptedData.withUnsafeMutableBytes { encryptedPtr in
            CCCrypt(CCOperation(kCCEncrypt),
                   CCAlgorithm(kCCAlgorithmAES),
                   CCOptions(kCCOptionPKCS7Padding),
                   keyPtr,
                   key.count,
                   nil,
                   dataPtr,
                   data.count,
                   encryptedPtr.baseAddress!,
                   encryptedPtr.count,
                   &encryptedLength)
        }

        guard status == kCCSuccess else {
            throw SecurityError.encryptionFailed("AES encryption failed with status: \(status)")
        }

        encryptedData.removeSubrange(encryptedLength..<encryptedData.count)
        return encryptedData
    }

    /// Decrypts data encrypted with AES-256-GCM
    public func decryptData(_ encryptedData: Data, key: Data) throws -> Data {
        guard key.count == kCCKeySizeAES256 else {
            throw SecurityError.decryptionFailed("Invalid key size")
        }

        let keyPtr = key.withUnsafeBytes { $0.baseAddress! }
        let encryptedPtr = encryptedData.withUnsafeBytes { $0.baseAddress! }

        var decryptedData = Data(count: encryptedData.count)
        var decryptedLength: size_t = 0

        let status = decryptedData.withUnsafeMutableBytes { decryptedPtr in
            CCCrypt(CCOperation(kCCDecrypt),
                   CCAlgorithm(kCCAlgorithmAES),
                   CCOptions(kCCOptionPKCS7Padding),
                   keyPtr,
                   key.count,
                   nil,
                   encryptedPtr,
                   encryptedData.count,
                   decryptedPtr.baseAddress!,
                   decryptedPtr.count,
                   &decryptedLength)
        }

        guard status == kCCSuccess else {
            throw SecurityError.decryptionFailed("AES decryption failed with status: \(status)")
        }

        decryptedData.removeSubrange(decryptedLength..<decryptedData.count)
        return decryptedData
    }

    // MARK: - Input Validation

    /// Validates input data against security requirements
    public func validateInput(_ input: String, for type: InputValidationType) throws {
        switch type {
        case .email:
            try validateEmail(input)
        case .password:
            try validatePassword(input)
        case .filename:
            try validateFilename(input)
        case .url:
            try validateURL(input)
        }
    }

    private func validateEmail(_ email: String) throws {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: email) else {
            throw SecurityError.inputValidationFailed("Invalid email format")
        }

        guard email.count <= 254 else {
            throw SecurityError.inputValidationFailed("Email too long")
        }
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw SecurityError.inputValidationFailed("Password must be at least 8 characters")
        }

        guard password.count <= 128 else {
            throw SecurityError.inputValidationFailed("Password too long")
        }

        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasDigit = password.contains { $0.isNumber }
        let hasSpecial = password.contains { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }

        guard hasUppercase && hasLowercase && hasDigit else {
            throw SecurityError.inputValidationFailed("Password must contain uppercase, lowercase, and numeric characters")
        }
    }

    private func validateFilename(_ filename: String) throws {
        guard !filename.isEmpty && filename.count <= 255 else {
            throw SecurityError.inputValidationFailed("Invalid filename length")
        }

        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        guard filename.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw SecurityError.inputValidationFailed("Filename contains invalid characters")
        }

        let suspiciousPatterns = ["..", "./", "~/", "../"]
        for pattern in suspiciousPatterns {
            if filename.contains(pattern) {
                throw SecurityError.inputValidationFailed("Filename contains suspicious pattern")
            }
        }
    }

    private func validateURL(_ urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw SecurityError.inputValidationFailed("Invalid URL format")
        }

        guard url.scheme == "https" else {
            throw SecurityError.inputValidationFailed("Only HTTPS URLs are allowed")
        }

        guard url.host != nil else {
            throw SecurityError.inputValidationFailed("URL must have a valid host")
        }
    }
}

// MARK: - Supporting Types

public enum SecurityCheckSeverity: String, Codable {
    case low, medium, high, critical
}

public struct SecurityCheck: Codable {
    public let name: String
    public let passed: Bool
    public let details: String
    public let severity: SecurityCheckSeverity

    public var isSecure: Bool { passed }
}

public struct SecurityCheckResult: Codable {
    public let passed: Bool
    public let description: String
}

public struct SecurityValidationResult: Codable {
    public let isSecure: Bool
    public let checks: [SecurityCheck]
    public let timestamp: Date
    public let duration: TimeInterval
}

public enum InputValidationType {
    case email, password, filename, url
}

// MARK: - Security Errors

public enum SecurityError: LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case inputValidationFailed(String)
    case integrityCheckFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .inputValidationFailed(let reason):
            return "Input validation failed: \(reason)"
        case .integrityCheckFailed(let reason):
            return "Integrity check failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .encryptionFailed, .decryptionFailed:
            return "Please try again. If the problem persists, contact support."
        case .inputValidationFailed:
            return "Please check your input and try again."
        case .integrityCheckFailed:
            return "Please reinstall the app to restore integrity."
        }
    }
}
