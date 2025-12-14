//
//  APIClient.swift
//  InteriorAI
//
//  Network client for API communications with security and error handling
//

import Foundation
import Combine

/// HTTP methods supported by the API client
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// API endpoint configuration
public struct APIEndpoint {
    public let path: String
    public let method: HTTPMethod
    public let requiresAuth: Bool
    public let timeout: TimeInterval?

    public init(path: String,
                method: HTTPMethod = .get,
                requiresAuth: Bool = false,
                timeout: TimeInterval? = nil) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
        self.timeout = timeout
    }

    /// Full URL for the endpoint
    public var url: URL? {
        return URL(string: APIConstants.baseURL)?
            .appendingPathComponent(APIConstants.apiVersion)
            .appendingPathComponent(path)
    }
}

/// Request body encoding types
public enum RequestEncoding {
    case json
    case urlEncoded
    case multipartData(boundary: String)
}

/// Response decoding types
public enum ResponseDecoding {
    case json
    case data
    case string(encoding: String.Encoding)
}

/// Network request configuration
public struct APIRequest {
    public let endpoint: APIEndpoint
    public let headers: [String: String]?
    public let body: Data?
    public let encoding: RequestEncoding
    public let queryParameters: [String: String]?

    public init(endpoint: APIEndpoint,
                headers: [String: String]? = nil,
                body: Data? = nil,
                encoding: RequestEncoding = .json,
                queryParameters: [String: String]? = nil) {
        self.endpoint = endpoint
        self.headers = headers
        self.body = body
        self.encoding = encoding
        self.queryParameters = queryParameters
    }
}

/// Network response
public struct APIResponse<T> {
    public let data: T
    public let response: HTTPURLResponse
    public let metrics: URLSessionTaskMetrics?

    public init(data: T, response: HTTPURLResponse, metrics: URLSessionTaskMetrics? = nil) {
        self.data = data
        self.response = response
        self.metrics = metrics
    }

    public var statusCode: Int {
        return response.statusCode
    }

    public var headers: [AnyHashable: Any] {
        return response.allHeaderFields
    }
}

/// Comprehensive API client with security, retry logic, and error handling
public final class APIClient {
    // MARK: - Singleton
    public static let shared = APIClient()

    // MARK: - Properties
    private let session: URLSession
    private let queue: DispatchQueue
    private let retryQueue: DispatchQueue

    private var authToken: String?
    private var refreshToken: String?

    // MARK: - Configuration
    private let maxConcurrentRequests: Int
    private let requestTimeout: TimeInterval
    private let resourceTimeout: TimeInterval
    private let maxRetries: Int
    private let retryDelay: TimeInterval

    private init() {
        // Configure URLSession with security
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = NetworkConstants.maxConcurrentRequests
        configuration.timeoutIntervalForRequest = NetworkConstants.requestTimeout
        configuration.timeoutIntervalForResource = NetworkConstants.resourceTimeout

        // Configure security
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        if #available(iOS 15.0, *) {
            configuration.tlsMinimumSupportedProtocol = .TLSv13
        }

        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        self.queue = DispatchQueue(label: "com.interiorai.apiclient", qos: .userInitiated)
        self.retryQueue = DispatchQueue(label: "com.interiorai.apiclient.retry", qos: .background)

        // Load configuration
        self.maxConcurrentRequests = NetworkConstants.maxConcurrentRequests
        self.requestTimeout = NetworkConstants.requestTimeout
        self.resourceTimeout = NetworkConstants.resourceTimeout
        self.maxRetries = APIConstants.retryAttempts
        self.retryDelay = APIConstants.retryDelay

        // Load authentication tokens
        loadAuthTokens()
    }

    // MARK: - Public API Methods

    /// Performs a network request with automatic retry and error handling
    /// - Parameters:
    ///   - request: The API request configuration
    ///   - decoding: How to decode the response
    /// - Returns: Publisher that emits the decoded response or an error
    public func performRequest<T: Decodable>(_ request: APIRequest,
                                           decoding: ResponseDecoding = .json) -> AnyPublisher<APIResponse<T>, APIError> {
        return performRequestWithRetry(request, decoding: decoding, attempt: 0)
    }

    /// Performs a network request and returns raw data
    /// - Parameter request: The API request configuration
    /// - Returns: Publisher that emits the raw response data
    public func performDataRequest(_ request: APIRequest) -> AnyPublisher<APIResponse<Data>, APIError> {
        return performRequestWithRetry(request, decoding: .data, attempt: 0)
    }

    /// Uploads data to the server
    /// - Parameters:
    ///   - request: The API request configuration with body data
    ///   - progress: Optional progress handler
    /// - Returns: Publisher that emits upload progress and final response
    public func uploadData(_ request: APIRequest,
                          progress: ((Double) -> Void)? = nil) -> AnyPublisher<APIResponse<Data>, APIError> {
        guard let url = buildURL(for: request) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        return queue.sync {
            do {
                let urlRequest = try buildURLRequest(for: request, url: url)

                Logger.shared.network("Starting data upload to \(url.absoluteString)")

                return session.dataTaskPublisher(for: urlRequest)
                    .handleEvents(receiveOutput: { output in
                        if let metrics = output.metrics {
                            self.logRequestMetrics(metrics, url: url)
                        }
                    })
                    .tryMap { output -> APIResponse<Data> in
                        let response = output.response as! HTTPURLResponse
                        let data = output.data

                        try self.validateResponse(response, data: data)

                        Logger.shared.network("Data upload completed successfully")
                        return APIResponse(data: data, response: response, metrics: output.metrics)
                    }
                    .mapError { error in
                        Logger.shared.network("Data upload failed: \(error.localizedDescription)", category: .network)
                        return self.mapToAPIError(error)
                    }
                    .eraseToAnyPublisher()

            } catch {
                Logger.shared.network("Failed to build upload request: \(error.localizedDescription)", category: .network)
                return Fail(error: mapToAPIError(error)).eraseToAnyPublisher()
            }
        }
    }

    // MARK: - Authentication

    /// Sets the authentication tokens
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: Optional refresh token
    public func setAuthTokens(accessToken: String, refreshToken: String? = nil) {
        self.authToken = accessToken
        self.refreshToken = refreshToken

        // Store in keychain
        do {
            try KeychainManager.shared.storeAuthTokens(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } catch {
            Logger.shared.error("Failed to store auth tokens in keychain", error: error, category: .security)
        }
    }

    /// Clears authentication tokens
    public func clearAuthTokens() {
        authToken = nil
        refreshToken = nil

        do {
            try KeychainManager.shared.deleteAuthTokens()
        } catch {
            Logger.shared.error("Failed to delete auth tokens from keychain", error: error, category: .security)
        }
    }

    /// Checks if the user is authenticated
    /// - Returns: True if valid auth tokens exist
    public func isAuthenticated() -> Bool {
        return KeychainManager.shared.hasValidAuthTokens()
    }

    // MARK: - Private Implementation

    private func performRequestWithRetry<T: Decodable>(_ request: APIRequest,
                                                     decoding: ResponseDecoding,
                                                     attempt: Int) -> AnyPublisher<APIResponse<T>, APIError> {
        return performSingleRequest(request, decoding: decoding)
            .catch { [weak self] error -> AnyPublisher<APIResponse<T>, APIError> in
                guard let self = self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }

                // Check if we should retry
                if self.shouldRetry(error: error, attempt: attempt) {
                    Logger.shared.network("Retrying request (attempt \(attempt + 1)/\(self.maxRetries))")

                    return self.retryQueue.delayPublisher(for: self.retryDelay)
                        .flatMap { _ in
                            self.performRequestWithRetry(request, decoding: decoding, attempt: attempt + 1)
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    private func performSingleRequest<T: Decodable>(_ request: APIRequest,
                                                  decoding: ResponseDecoding) -> AnyPublisher<APIResponse<T>, APIError> {
        guard let url = buildURL(for: request) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        return queue.sync {
            do {
                let urlRequest = try buildURLRequest(for: request, url: url)

                Logger.shared.network("Starting request: \(request.endpoint.method.rawValue) \(url.absoluteString)")

                return session.dataTaskPublisher(for: urlRequest)
                    .handleEvents(receiveOutput: { output in
                        if let metrics = output.metrics {
                            self.logRequestMetrics(metrics, url: url)
                        }
                    })
                    .tryMap { output -> APIResponse<T> in
                        let response = output.response as! HTTPURLResponse
                        let data = output.data

                        try self.validateResponse(response, data: data)

                        let decodedData: T = try self.decodeResponse(data, decoding: decoding)

                        Logger.shared.network("Request completed successfully")
                        return APIResponse(data: decodedData, response: response, metrics: output.metrics)
                    }
                    .mapError { error in
                        Logger.shared.network("Request failed: \(error.localizedDescription)", category: .network)
                        return self.mapToAPIError(error)
                    }
                    .eraseToAnyPublisher()

            } catch {
                Logger.shared.network("Failed to build request: \(error.localizedDescription)", category: .network)
                return Fail(error: mapToAPIError(error)).eraseToAnyPublisher()
            }
        }
    }

    private func buildURL(for request: APIRequest) -> URL? {
        guard var url = request.endpoint.url else { return nil }

        // Add query parameters
        if let queryParameters = request.queryParameters, !queryParameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }

            if let finalURL = components?.url {
                url = finalURL
            }
        }

        return url
    }

    private func buildURLRequest(for request: APIRequest, url: URL) throws -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.endpoint.method.rawValue
        urlRequest.timeoutInterval = request.endpoint.timeout ?? requestTimeout

        // Set headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(AppConstants.appVersion, forHTTPHeaderField: "X-App-Version")
        urlRequest.setValue(UIDevice.current.model, forHTTPHeaderField: "X-Device-Model")

        // Add custom headers
        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add authentication if required
        if request.endpoint.requiresAuth {
            if let accessToken = authToken {
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                throw APIError.authenticationRequired
            }
        }

        // Set body
        if let body = request.body {
            urlRequest.httpBody = body

            // Set content type based on encoding
            switch request.encoding {
            case .json:
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            case .urlEncoded:
                urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            case .multipartData(let boundary):
                urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            }
        }

        return urlRequest
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        let statusCode = response.statusCode

        // Check for authentication errors
        if statusCode == 401 {
            // Clear invalid tokens
            clearAuthTokens()
            throw APIError.authenticationFailed
        }

        // Check for client errors
        if statusCode >= 400 && statusCode < 500 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: statusCode, message: errorResponse.message)
            } else {
                throw APIError.clientError(statusCode: statusCode)
            }
        }

        // Check for server errors
        if statusCode >= 500 {
            throw APIError.serverError(statusCode: statusCode, message: "Internal server error")
        }

        // Validate content type for JSON responses
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("application/json") {
            // Additional JSON validation could go here
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data, decoding: ResponseDecoding) throws -> T {
        switch decoding {
        case .json:
            return try JSONDecoder().decode(T.self, from: data)
        case .data:
            if let dataResponse = data as? T {
                return dataResponse
            } else {
                throw APIError.decodingFailed("Cannot cast data to expected type")
            }
        case .string(let encoding):
            guard let string = String(data: data, encoding: encoding) else {
                throw APIError.decodingFailed("Failed to decode data as string")
            }
            if let stringResponse = string as? T {
                return stringResponse
            } else {
                throw APIError.decodingFailed("Cannot cast string to expected type")
            }
        }
    }

    private func shouldRetry(error: APIError, attempt: Int) -> Bool {
        // Don't retry if we've exceeded max attempts
        guard attempt < maxRetries else { return false }

        // Retry on network errors and server errors (5xx)
        switch error {
        case .networkError, .timeout:
            return true
        case .serverError(let statusCode, _):
            return statusCode >= 500
        default:
            return false
        }
    }

    private func mapToAPIError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }

        // Map network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost:
                return .hostUnreachable
            default:
                return .networkError
            }
        }

        // Map decoding errors
        if error is DecodingError {
            return .decodingFailed(error.localizedDescription)
        }

        return .unknown(error)
    }

    private func loadAuthTokens() {
        do {
            let tokens = try KeychainManager.shared.retrieveAuthTokens()
            authToken = tokens.accessToken
            refreshToken = tokens.refreshToken
        } catch {
            // No stored tokens or failed to retrieve - this is expected
            Logger.shared.debug("No stored auth tokens found", category: .security)
        }
    }

    private func logRequestMetrics(_ metrics: URLSessionTaskMetrics, url: URL) {
        let transactionMetrics = metrics.transactionMetrics.first
        if let duration = transactionMetrics?.requestEndDate?.timeIntervalSince(transactionMetrics?.requestStartDate ?? Date()) {
            Logger.shared.network("Request to \(url.absoluteString) completed in \(String(format: "%.3f", duration))s",
                                category: .performance)
        }
    }
}

// MARK: - Supporting Types

/// API error types
public enum APIError: LocalizedError {
    case invalidURL
    case networkError
    case timeout
    case hostUnreachable
    case authenticationRequired
    case authenticationFailed
    case clientError(statusCode: Int)
    case serverError(statusCode: Int, message: String)
    case decodingFailed(String)
    case encodingFailed(String)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network connection error"
        case .timeout:
            return "Request timed out"
        case .hostUnreachable:
            return "Server unreachable"
        case .authenticationRequired:
            return "Authentication required"
        case .authenticationFailed:
            return "Authentication failed"
        case .clientError(let statusCode):
            return "Client error (HTTP \(statusCode))"
        case .serverError(let statusCode, let message):
            return "Server error (HTTP \(statusCode)): \(message)"
        case .decodingFailed(let reason):
            return "Failed to decode response: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to encode request: \(reason)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .networkError, .hostUnreachable:
            return "Please check your internet connection and try again."
        case .timeout:
            return "Please try again. The request may take longer in poor network conditions."
        case .authenticationRequired, .authenticationFailed:
            return "Please sign in again."
        case .clientError(let statusCode) where statusCode == 429:
            return "Too many requests. Please wait a moment before trying again."
        case .serverError:
            return "Server temporarily unavailable. Please try again later."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }
}

/// API error response from server
public struct APIErrorResponse: Codable {
    public let error: String
    public let message: String
    public let code: Int?

    private enum CodingKeys: String, CodingKey {
        case error, message, code
    }
}

// MARK: - Extensions

extension DispatchQueue {
    /// Creates a publisher that emits after the specified delay
    func delayPublisher(for delay: TimeInterval) -> AnyPublisher<Void, Never> {
        Future { promise in
            self.asyncAfter(deadline: .now() + delay) {
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Convenience Extensions

public extension APIClient {
    /// Performs a GET request
    func get<T: Decodable>(_ path: String,
                          headers: [String: String]? = nil,
                          queryParameters: [String: String]? = nil,
                          requiresAuth: Bool = false) -> AnyPublisher<APIResponse<T>, APIError> {
        let endpoint = APIEndpoint(path: path, method: .get, requiresAuth: requiresAuth)
        let request = APIRequest(endpoint: endpoint, headers: headers, queryParameters: queryParameters)
        return performRequest(request)
    }

    /// Performs a POST request
    func post<T: Decodable>(_ path: String,
                           body: Encodable? = nil,
                           headers: [String: String]? = nil,
                           requiresAuth: Bool = false) -> AnyPublisher<APIResponse<T>, APIError> {
        let endpoint = APIEndpoint(path: path, method: .post, requiresAuth: requiresAuth)
        let request = APIRequest(endpoint: endpoint, headers: headers, body: encodeBody(body))
        return performRequest(request)
    }

    /// Performs a PUT request
    func put<T: Decodable>(_ path: String,
                          body: Encodable? = nil,
                          headers: [String: String]? = nil,
                          requiresAuth: Bool = false) -> AnyPublisher<APIResponse<T>, APIError> {
        let endpoint = APIEndpoint(path: path, method: .put, requiresAuth: requiresAuth)
        let request = APIRequest(endpoint: endpoint, headers: headers, body: encodeBody(body))
        return performRequest(request)
    }

    /// Performs a DELETE request
    func delete<T: Decodable>(_ path: String,
                             headers: [String: String]? = nil,
                             requiresAuth: Bool = false) -> AnyPublisher<APIResponse<T>, APIError> {
        let endpoint = APIEndpoint(path: path, method: .delete, requiresAuth: requiresAuth)
        let request = APIRequest(endpoint: endpoint, headers: headers)
        return performRequest(request)
    }

    private func encodeBody(_ body: Encodable?) -> Data? {
        guard let body = body else { return nil }
        do {
            return try JSONEncoder().encode(body)
        } catch {
            Logger.shared.error("Failed to encode request body", error: error, category: .network)
            return nil
        }
    }
}
