//
//  NetworkManager.swift
//  AppleInference
//
//  Created by Dennis Stewart Jr. on 11/23/25.
//

import Foundation

/// Production-ready network manager with comprehensive error handling and retry logic
class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let retryStrategy = RetryStrategy()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds for requests
        config.timeoutIntervalForResource = 300.0 // 5 minutes for resources
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 5
        self.session = URLSession(configuration: config)
    }

    /// Perform network request with automatic retry logic
    func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await retryStrategy.execute {
            let (data, response) = try await self.session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                return (data, httpResponse)
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 429:
                throw NetworkError.rateLimited
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        }
    }

    /// Check if device has internet connectivity
    func isConnectedToInternet() async -> Bool {
        // Simple connectivity check - in production, use NWPathMonitor
        do {
            let testRequest = URLRequest(url: URL(string: "https://www.google.com")!)
            _ = try await session.data(for: testRequest)
            return true
        } catch {
            return false
        }
    }
}

/// Comprehensive network error types
enum NetworkError: LocalizedError {
    case noInternetConnection
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case invalidResponse
    case decodingError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .unauthorized:
            return "Invalid API key. Please check your credentials in Settings."
        case .forbidden:
            return "Access forbidden. Please check your API permissions."
        case .notFound:
            return "Resource not found. Please try again later."
        case .rateLimited:
            return "Rate limit exceeded. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code):
            return "HTTP error (\(code)). Please check your connection."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .decodingError:
            return "Failed to process server response. Please try again."
        case .unknown(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Retry strategy with exponential backoff
struct RetryStrategy {
    let maxAttempts: Int = 3
    let initialDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 30.0
    let backoffMultiplier: Double = 2.0

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch let error as NetworkError {
                lastError = error

                // Don't retry certain errors
                switch error {
                case .unauthorized, .forbidden, .notFound:
                    throw error
                default:
                    break
                }

                // If this was the last attempt, throw the error
                if attempt == maxAttempts - 1 {
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = min(initialDelay * pow(backoffMultiplier, Double(attempt)), maxDelay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                lastError = error

                // If this was the last attempt, throw the error
                if attempt == maxAttempts - 1 {
                    throw NetworkError.unknown(error)
                }

                // Calculate delay with exponential backoff
                let delay = min(initialDelay * pow(backoffMultiplier, Double(attempt)), maxDelay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? NetworkError.unknown(NSError(domain: "RetryError", code: -1))
    }
}
