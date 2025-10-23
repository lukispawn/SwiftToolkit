//
//  LoggerFormatter.swift
//  SwiftToolkit
//
//  Structured logging utilities for consistent log formatting
//

import Foundation

// MARK: - String Extension for Structured Logging

internal extension String {
    /// Create a structured log message with consistent formatting
    ///
    /// **Format**: `[action] status | key1: value1 | key2: value2`
    ///
    /// **Usage**:
    /// ```swift
    /// logger.log(.debug, .structuredLog(
    ///     action: "cache",
    ///     status: "hit",
    ///     params: [("key", "user123"), ("ttl", "3600")]
    /// ))
    /// // Output: [cache] hit | key: user123 | ttl: 3600
    /// ```
    ///
    /// - Parameters:
    ///   - action: Action being performed (e.g., "cache", "request", "process")
    ///   - status: Optional status of the action (e.g., "hit", "success", "failed")
    ///   - params: Optional key-value pairs for additional context
    ///   - error: Optional error to append to params
    /// - Returns: Formatted log message string
    static func structuredLog(
        action: String,
        status: String? = nil,
        params: [(String, String)] = [],
        error: Error? = nil
    ) -> String {
        var finalParams = params
        if let error = error {
            finalParams.append(("error", error.localizedDescription))
        }

        let finalStatus = status ?? (error != nil ? "failed" : nil)

        return formatStructuredLog(
            action: action,
            status: finalStatus,
            params: finalParams
        )
    }

    /// Format structured log message with standard structure
    ///
    /// - Parameters:
    ///   - action: Action identifier
    ///   - status: Optional status string
    ///   - params: Key-value pairs for additional context
    /// - Returns: Formatted message string
    static func formatStructuredLog(
        action: String,
        status: String? = nil,
        params: [(String, String)] = []
    ) -> String {
        var message = "[\(action)]"

        if let status = status {
            message += " \(status)"
        }

        for (key, value) in params {
            message += " | \(key): \(value)"
        }

        return message
    }
}
