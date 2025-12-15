//
//  Logger.swift
//  InteriorAI
//
//  Comprehensive logging infrastructure for the InteriorAI application
//

import Foundation
import os.log
import UIKit

/// Log levels for different types of messages
public enum LogLevel: Int, Comparable, Codable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    public var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Log categories for organizing log messages
public enum LogCategory: String, Codable, CaseIterable {
    case general = "General"
    case security = "Security"
    case network = "Network"
    case storage = "Storage"
    case lidar = "LiDAR"
    case detection = "Detection"
    case ui = "UI"
    case performance = "Performance"
    case lifecycle = "Lifecycle"
}

/// Comprehensive logger for the InteriorAI application
public final class Logger {
    // MARK: - Singleton
    public static let shared = Logger()

    // MARK: - Properties
    private let queue: DispatchQueue
    private let fileManager: FileManager
    private let dateFormatter: DateFormatter
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private var logFileURL: URL?
    private var currentLogFileSize: Int64 = 0
    private var osLoggers: [LogCategory: OSLog] = [:]

    // MARK: - Configuration
    private let maxFileSize: Int64
    private let maxFileCount: Int
    private let currentLogLevel: LogLevel
    private let enableRemoteLogging: Bool

    private init() {
        self.queue = DispatchQueue(label: "com.interiorai.logger", qos: .utility)
        self.fileManager = FileManager.default

        // Configure date formatter
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.timeZone = TimeZone.current

        // Configure JSON encoder/decoder
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601

        // Load configuration from constants
        self.maxFileSize = LoggingConstants.maxLogFileSize
        self.maxFileCount = LoggingConstants.maxLogFiles
        self.currentLogLevel = LogLevel(rawValue: LoggingConstants.logLevel == "DEBUG" ? 0 :
                                       LoggingConstants.logLevel == "INFO" ? 1 :
                                       LoggingConstants.logLevel == "WARNING" ? 2 :
                                       LoggingConstants.logLevel == "ERROR" ? 3 : 4) ?? .info
        self.enableRemoteLogging = LoggingConstants.enableRemoteLogging

        setupLoggingInfrastructure()
    }

    // MARK: - Setup
    private func setupLoggingInfrastructure() {
        // Create logs directory if needed
        guard getLogsDirectory() != nil else {
            print("Failed to create logs directory")
            return
        }

        // Initialize OSLog loggers for each category
        for category in LogCategory.allCases {
            osLoggers[category] = OSLog(subsystem: AppConstants.appBundleId, category: category.rawValue)
        }

        // Setup log file rotation
        rotateLogFilesIfNeeded()

        // Setup current log file
        setupCurrentLogFile()
    }

    private func getLogsDirectory() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let logsDirectory = documentsDirectory.appendingPathComponent("Logs", isDirectory: true)

        do {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
            return logsDirectory
        } catch {
            logError("Failed to create logs directory: \(error.localizedDescription)", category: .general)
            return nil
        }
    }

    private func setupCurrentLogFile() {
        guard let logsDirectory = getLogsDirectory() else { return }

        let dateString = dateFormatter.string(from: Date()).prefix(10) // YYYY-MM-DD
        let filename = "interiorai_\(dateString).log"
        logFileURL = logsDirectory.appendingPathComponent(filename)

        // Check if file exists and get its size
        if let logFileURL = logFileURL,
           fileManager.fileExists(atPath: logFileURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: logFileURL.path)
                currentLogFileSize = attributes[.size] as? Int64 ?? 0
            } catch {
                logError("Failed to get log file size: \(error.localizedDescription)", category: .general)
            }
        }
    }

    // MARK: - Public Logging Methods

    /// Logs a debug message
    public func debug(_ message: String,
                     category: LogCategory = .general,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Logs an info message
    public func info(_ message: String,
                    category: LogCategory = .general,
                    file: String = #file,
                    function: String = #function,
                    line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Logs a warning message
    public func warning(_ message: String,
                       category: LogCategory = .general,
                       file: String = #file,
                       function: String = #function,
                       line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Logs an error message
    public func error(_ message: String,
                     error: Error? = nil,
                     category: LogCategory = .general,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Logs a critical message
    public func critical(_ message: String,
                        error: Error? = nil,
                        category: LogCategory = .general,
                        file: String = #file,
                        function: String = #function,
                        line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private Logging Implementation

    private func log(_ message: String,
                    level: LogLevel,
                    category: LogCategory,
                    file: String,
                    function: String,
                    line: Int) {
        // Check if we should log this level
        guard level >= currentLogLevel else { return }

        queue.async { [weak self] in
            self?.performLogging(message, level: level, category: category, file: file, function: function, line: line)
        }
    }

    private func performLogging(_ message: String,
                               level: LogLevel,
                               category: LogCategory,
                               file: String,
                               function: String,
                               line: Int) {
        let timestamp = Date()
        let filename = (file as NSString).lastPathComponent

        // Create log entry
        let logEntry = LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            file: filename,
            function: function,
            line: line,
            thread: Thread.current.name ?? "main",
            deviceInfo: getDeviceInfo()
        )

        // Log to console/OSLog
        logToConsole(logEntry)

        // Log to file
        logToFile(logEntry)

        // Send to remote logging if enabled
        if enableRemoteLogging && level >= .warning {
            sendRemoteLog(logEntry)
        }
    }

    private func logToConsole(_ entry: LogEntry) {
        let osLog = osLoggers[entry.category] ?? OSLog.default

        let consoleMessage = formatConsoleMessage(entry)

        switch entry.level {
        case .debug:
            os_log(.debug, log: osLog, "%{public}@", consoleMessage)
        case .info:
            os_log(.info, log: osLog, "%{public}@", consoleMessage)
        case .warning:
            os_log(.default, log: osLog, "%{public}@", consoleMessage)
        case .error, .critical:
            os_log(.error, log: osLog, "%{public}@", consoleMessage)
        }
    }

    private func logToFile(_ entry: LogEntry) {
        guard let logFileURL = logFileURL else { return }

        do {
            // Check if we need to rotate the log file
            if currentLogFileSize >= maxFileSize {
                rotateLogFilesIfNeeded()
                setupCurrentLogFile()
            }

            // Format message for file
            let fileMessage = formatFileMessage(entry) + "\n"

            // Write to file
            if fileManager.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = fileMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try fileMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
            }

            // Update file size
            currentLogFileSize += Int64(fileMessage.count)

        } catch {
            // Don't recursively log file write errors
            print("Failed to write to log file: \(error.localizedDescription)")
        }
    }

    private func sendRemoteLog(_ entry: LogEntry) {
        // Placeholder for remote logging implementation
        // This would send logs to a remote server for monitoring
        queue.asyncAfter(deadline: .now() + 1) {
            // Simulate network request
            // In real implementation, this would use APIClient
        }
    }

    // MARK: - Formatting

    private func formatConsoleMessage(_ entry: LogEntry) -> String {
        return "\(entry.level.emoji) [\(entry.category.rawValue)] \(entry.message)"
    }

    private func formatFileMessage(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        return "\(timestamp) [\(entry.level.description)] [\(entry.category.rawValue)] [\(entry.file):\(entry.line)] \(entry.message)"
    }

    // MARK: - File Management

    private func rotateLogFilesIfNeeded() {
        guard let logsDirectory = getLogsDirectory() else { return }

        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { (url1, url2) -> Bool in
                    do {
                        let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                        let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                        return date1 > date2
                    } catch {
                        return false
                    }
                }

            // Keep only the most recent files
            if logFiles.count >= maxFileCount {
                for fileURL in logFiles[maxFileCount...] {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            logError("Failed to rotate log files: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Device Info

    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: AppConstants.appVersion
        )
    }

    // MARK: - Log Retrieval

    /// Retrieves recent log entries
    /// - Parameter limit: Maximum number of entries to retrieve
    /// - Returns: Array of log entries
    public func getRecentLogs(limit: Int = 100) -> [LogEntry] {
        guard let logFileURL = logFileURL,
              fileManager.fileExists(atPath: logFileURL.path) else {
            return []
        }

        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .suffix(limit)

            // Parse lines into LogEntry objects (simplified parsing)
            return lines.compactMap { line in
                // This is a simplified parser - in production you'd want more robust parsing
                parseLogLine(line)
            }
        } catch {
            logError("Failed to read log file: \(error.localizedDescription)", category: .general)
            return []
        }
    }

    private func parseLogLine(_ line: String) -> LogEntry? {
        // Simplified log line parsing
        // Format: "timestamp [LEVEL] [CATEGORY] [file:line] message"
        let components = line.components(separatedBy: " ")
        guard components.count >= 4 else { return nil }

        let timestampString = components[0]
        let levelString = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let categoryString = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        guard let timestamp = dateFormatter.date(from: timestampString),
              let level = LogLevel.allCases.first(where: { $0.description == levelString }),
              let category = LogCategory.allCases.first(where: { $0.rawValue == categoryString }) else {
            return nil
        }

        let message = components.dropFirst(4).joined(separator: " ")

        return LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            file: "unknown",
            function: "unknown",
            line: 0,
            thread: "unknown",
            deviceInfo: getDeviceInfo()
        )
    }

    // MARK: - Performance Logging

    /// Logs performance metrics
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - duration: Duration in seconds
    ///   - metadata: Additional metadata
    public func logPerformance(_ operation: String,
                              duration: TimeInterval,
                              metadata: [String: Any]? = nil) {
        var message = "Performance: \(operation) took \(String(format: "%.3f", duration))s"
        if let metadata = metadata {
            message += " - \(metadata.description)"
        }

        log(message, level: .info, category: .performance, file: #file, function: #function, line: #line)
    }

    /// Measures execution time of a block
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - block: Block to execute and measure
    /// - Returns: Result of the block
    public func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)
        logPerformance(operation, duration: duration)
        return result
    }
}

// MARK: - Supporting Types

/// Individual log entry
public struct LogEntry: Codable, Equatable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let thread: String
    public let deviceInfo: DeviceInfo
}

/// Device information for logging
public struct DeviceInfo: Codable, Equatable {
    public let model: String
    public let systemVersion: String
    public let appVersion: String
}

// MARK: - Convenience Extensions

public extension Logger {
    /// Logs security-related events
    func security(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .security, file: file, function: function, line: line)
    }

    /// Logs network-related events
    func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .network, file: file, function: function, line: line)
    }

    /// Logs LiDAR-related events
    func lidar(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .lidar, file: file, function: function, line: line)
    }

    /// Logs detection-related events
    func detection(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .detection, file: file, function: function, line: line)
    }

    /// Logs lifecycle-related events
    func lifecycle(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: .lifecycle, file: file, function: function, line: line)
    }
}

// MARK: - Global Convenience Functions

/// Global debug logging function
public func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

/// Global info logging function
public func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

/// Global warning logging function
public func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

/// Global error logging function
public func logError(_ message: String, error: Error? = nil, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, error: error, category: category, file: file, function: function, line: line)
}

/// Global critical logging function
public func logCritical(_ message: String, error: Error? = nil, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, error: error, category: category, file: file, function: function, line: line)
}

