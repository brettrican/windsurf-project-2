//
//  KeychainManager.swift
//  InteriorAI
//
//  Secure keychain storage for sensitive data
//

import Foundation
import Security

/// Keychain manager for secure storage of sensitive data
public final class KeychainManager {
    // MARK: - Singleton
    public static let shared = KeychainManager()

    private init() {}

    // MARK: - Public Interface

    /// Stores data securely in the keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: Unique identifier for the data
    ///   - accessibility: When the data should be accessible
    /// - Throws: KeychainError if storage fails
    public func storeData(_ data: Data, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlock) throws {
        // First, delete any existing item with this key
        try deleteData(forKey: key)

        // Prepare the query for storing
        var query = createBaseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessibility.value

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    /// Retrieves data from the keychain
    /// - Parameter key: Unique identifier for the data
    /// - Returns: The stored data
    /// - Throws: KeychainError if retrieval fails
    public func retrieveData(forKey key: String) throws -> Data {
        var query = createBaseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    /// Deletes data from the keychain
    /// - Parameter key: Unique identifier for the data
    /// - Throws: KeychainError if deletion fails
    public func deleteData(forKey key: String) throws {
        let query = createBaseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        // Ignore error if item doesn't exist
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Checks if data exists for a given key
    /// - Parameter key: Unique identifier for the data
    /// - Returns: True if data exists
    public func dataExists(forKey key: String) -> Bool {
        do {
            _ = try retrieveData(forKey: key)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Convenience Methods for Strings

    /// Stores a string securely in the keychain
    /// - Parameters:
    ///   - string: The string to store
    ///   - key: Unique identifier for the string
    ///   - accessibility: When the data should be accessible
    /// - Throws: KeychainError if storage fails
    public func storeString(_ string: String, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlock) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try storeData(data, forKey: key, accessibility: accessibility)
    }

    /// Retrieves a string from the keychain
    /// - Parameter key: Unique identifier for the string
    /// - Returns: The stored string
    /// - Throws: KeychainError if retrieval fails
    public func retrieveString(forKey key: String) throws -> String {
        let data = try retrieveData(forKey: key)
        guard let string = String(data: data, using: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Convenience Methods for Codable Objects

    /// Stores a Codable object securely in the keychain
    /// - Parameters:
    ///   - object: The object to store
    ///   - key: Unique identifier for the object
    ///   - accessibility: When the data should be accessible
    /// - Throws: KeychainError if storage or encoding fails
    public func storeObject<T: Codable>(_ object: T, forKey key: String, accessibility: KeychainAccessibility = .afterFirstUnlock) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try storeData(data, forKey: key, accessibility: accessibility)
    }

    /// Retrieves a Codable object from the keychain
    /// - Parameters:
    ///   - key: Unique identifier for the object
    ///   - type: The type of the object to retrieve
    /// - Returns: The decoded object
    /// - Throws: KeychainError if retrieval or decoding fails
    public func retrieveObject<T: Codable>(forKey key: String, type: T.Type) throws -> T {
        let data = try retrieveData(forKey: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - Authentication Tokens

    /// Stores authentication tokens securely
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: Optional refresh token
    ///   - expirationDate: When the access token expires
    /// - Throws: KeychainError if storage fails
    public func storeAuthTokens(accessToken: String, refreshToken: String? = nil, expirationDate: Date? = nil) throws {
        let tokens = AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expirationDate: expirationDate
        )
        try storeObject(tokens, forKey: KeychainKeys.authTokens, accessibility: .afterFirstUnlock)
    }

    /// Retrieves authentication tokens
    /// - Returns: The stored authentication tokens
    /// - Throws: KeychainError if retrieval fails
    public func retrieveAuthTokens() throws -> AuthTokens {
        return try retrieveObject(forKey: KeychainKeys.authTokens, type: AuthTokens.self)
    }

    /// Deletes stored authentication tokens
    /// - Throws: KeychainError if deletion fails
    public func deleteAuthTokens() throws {
        try deleteData(forKey: KeychainKeys.authTokens)
    }

    /// Checks if authentication tokens exist and are valid
    /// - Returns: True if valid tokens exist
    public func hasValidAuthTokens() -> Bool {
        do {
            let tokens = try retrieveAuthTokens()
            if let expirationDate = tokens.expirationDate {
                return expirationDate > Date()
            }
            return true // No expiration date means token is valid
        } catch {
            return false
        }
    }

    // MARK: - User Credentials

    /// Stores user credentials securely
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    /// - Throws: KeychainError if storage fails
    public func storeCredentials(username: String, password: String) throws {
        let credentials = UserCredentials(username: username, password: password)
        try storeObject(credentials, forKey: KeychainKeys.userCredentials, accessibility: .afterFirstUnlock)
    }

    /// Retrieves user credentials
    /// - Returns: The stored user credentials
    /// - Throws: KeychainError if retrieval fails
    public func retrieveCredentials() throws -> UserCredentials {
        return try retrieveObject(forKey: KeychainKeys.userCredentials, type: UserCredentials.self)
    }

    /// Deletes stored user credentials
    /// - Throws: KeychainError if deletion fails
    public func deleteCredentials() throws {
        try deleteData(forKey: KeychainKeys.userCredentials)
    }

    // MARK: - Encryption Keys

    /// Generates and stores a new encryption key
    /// - Parameter keyId: Unique identifier for the key
    /// - Returns: The generated key data
    /// - Throws: KeychainError if generation or storage fails
    public func generateAndStoreEncryptionKey(keyId: String) throws -> Data {
        var keyData = Data(count: 32) // 256 bits
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw KeychainError.keyGenerationFailed(result)
        }

        try storeData(keyData, forKey: keyId, accessibility: .afterFirstUnlock)
        return keyData
    }

    /// Retrieves an encryption key
    /// - Parameter keyId: Unique identifier for the key
    /// - Returns: The encryption key data
    /// - Throws: KeychainError if retrieval fails
    public func retrieveEncryptionKey(keyId: String) throws -> Data {
        return try retrieveData(forKey: keyId)
    }

    // MARK: - Biometric Authentication

    /// Stores biometric authentication state
    /// - Parameter enabled: Whether biometric auth is enabled
    /// - Throws: KeychainError if storage fails
    public func storeBiometricState(_ enabled: Bool) throws {
        let state = BiometricState(enabled: enabled, lastUsed: Date())
        try storeObject(state, forKey: KeychainKeys.biometricState, accessibility: .afterFirstUnlock)
    }

    /// Retrieves biometric authentication state
    /// - Returns: The biometric state
    /// - Throws: KeychainError if retrieval fails
    public func retrieveBiometricState() throws -> BiometricState {
        return try retrieveObject(forKey: KeychainKeys.biometricState, type: BiometricState.self)
    }

    // MARK: - Private Helper Methods

    private func createBaseQuery(forKey key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConstants.keychainServiceName,
            kSecAttrAccount as String: key
        ]
    }

    // MARK: - Bulk Operations

    /// Clears all InteriorAI-related data from the keychain
    /// - Throws: KeychainError if any deletion fails
    public func clearAllData() throws {
        let keysToDelete = [
            KeychainKeys.authTokens,
            KeychainKeys.userCredentials,
            KeychainKeys.biometricState
        ]

        for key in keysToDelete {
            try? deleteData(forKey: key) // Ignore individual failures
        }

        // Also clear any encryption keys (they start with "encryption_key_")
        try clearEncryptionKeys()
    }

    /// Clears all stored encryption keys
    /// - Throws: KeychainError if deletion fails
    public func clearEncryptionKeys() throws {
        // This is a simplified implementation
        // In a real app, you'd need to query for all keys with a specific pattern
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SecurityConstants.keychainServiceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   account.hasPrefix("encryption_key_") {
                    try deleteData(forKey: account)
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Keychain accessibility levels
public enum KeychainAccessibility {
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly

    var value: CFString {
        switch self {
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}

/// Keychain key constants
public enum KeychainKeys {
    static let authTokens = "auth_tokens"
    static let userCredentials = "user_credentials"
    static let biometricState = "biometric_state"
    static let encryptionKeyPrefix = "encryption_key_"

    static func encryptionKey(forId id: String) -> String {
        return "\(encryptionKeyPrefix)\(id)"
    }
}

/// Authentication tokens structure
public struct AuthTokens: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expirationDate: Date?

    public var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() >= expirationDate
    }
}

/// User credentials structure
public struct UserCredentials: Codable, Equatable {
    public let username: String
    public let password: String
}

/// Biometric authentication state
public struct BiometricState: Codable, Equatable {
    public let enabled: Bool
    public let lastUsed: Date
}

// MARK: - Keychain Errors

public enum KeychainError: LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case keyGenerationFailed(OSStatus)
    case invalidData
    case itemNotFound

    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store data in keychain (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve data from keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete data from keychain (status: \(status))"
        case .keyGenerationFailed(let status):
            return "Failed to generate encryption key (status: \(status))"
        case .invalidData:
            return "Invalid data format in keychain"
        case .itemNotFound:
            return "Requested item not found in keychain"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .storeFailed, .retrieveFailed, .deleteFailed:
            return "Please check device storage and try again. If the problem persists, restart the device."
        case .keyGenerationFailed:
            return "Unable to generate secure encryption key. Please contact support."
        case .invalidData:
            return "Stored data appears to be corrupted. Please sign in again."
        case .itemNotFound:
            return "Please sign in to restore your data."
        }
    }
}
