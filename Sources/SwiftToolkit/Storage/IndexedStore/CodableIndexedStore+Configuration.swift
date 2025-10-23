//
//  CodableIndexedStore+Configuration.swift
//  SwiftToolkit
//
//  Configuration and debug settings for CodableIndexedStore
//

import Foundation

// MARK: - Configuration

extension CodableIndexedStore {

    /// Configuration for store behavior
    public struct Configuration: Sendable {
        /// Pretty-print JSON for debugging
        public let prettyPrintJSON: Bool

        /// Auto-create directory if missing
        public let autoCreateDirectory: Bool

        /// Validate filenames for security
        public let validateFilenames: Bool

        /// Recreate store if manifest decoding fails (useful for development)
        ///
        /// **Warning**: When enabled, decoding errors will DELETE all data and start fresh.
        /// Only use during development when data model changes frequently.
        ///
        /// **Behavior**:
        /// - On manifest decode error: Deletes manifest + all item files, creates new empty store
        /// - On item decode error: Individual items fail normally (no recreation)
        public let recreateOnDecodingError: Bool

        /// Custom JSON encoder (optional)
        public let encoder: JSONEncoder?

        /// Custom JSON decoder (optional)
        public let decoder: JSONDecoder?

        /// Custom logger (optional)
        public let logger: LoggerWrapper?

        /// Storage mode (file or memory)
        public let storageMode: StorageMode

        public init(
            prettyPrintJSON: Bool = false,
            autoCreateDirectory: Bool = true,
            validateFilenames: Bool = true,
            recreateOnDecodingError: Bool = false,
            encoder: JSONEncoder? = nil,
            decoder: JSONDecoder? = nil,
            logger: LoggerWrapper? = nil,
            storageMode: StorageMode = .file
        ) {
            self.prettyPrintJSON = prettyPrintJSON
            self.autoCreateDirectory = autoCreateDirectory
            self.validateFilenames = validateFilenames
            self.recreateOnDecodingError = recreateOnDecodingError
            self.encoder = encoder
            self.decoder = decoder
            self.logger = logger
            self.storageMode = storageMode
        }
    }

    /// Storage mode for CodableIndexedStore
    public enum StorageMode: Sendable {
        /// Write to disk (default)
        case file

        /// Keep in memory only (for testing)
        case memory
    }

    /// Debug settings for testing
    public struct DebugSettings: Sendable {
        /// Simulate delays for testing
        public let simulateDelay: TimeInterval?

        /// Log operations
        public let logOperations: Bool

        public init(simulateDelay: TimeInterval? = nil, logOperations: Bool = false) {
            self.simulateDelay = simulateDelay
            self.logOperations = logOperations
        }
    }
}

// MARK: - Configuration Presets

extension CodableIndexedStore.Configuration {

    /// ISO8601 date encoding with pretty printing
    ///
    /// **Use when**: Need human-readable JSON with standard date format
    ///
    /// **Features**:
    /// - Pretty printed JSON
    /// - ISO8601 date encoding/decoding
    /// - Sorted keys
    public static var iso8601: Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return .init(
            prettyPrintJSON: true,
            encoder: encoder,
            decoder: decoder
        )
    }

    /// Compact JSON with minimal formatting
    ///
    /// **Use when**: Want smallest file sizes
    ///
    /// **Features**:
    /// - No pretty printing
    /// - Default date encoding (timestamp)
    /// - Compact output
    public static var compact: Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []

        return .init(
            prettyPrintJSON: false,
            encoder: encoder,
            decoder: JSONDecoder()
        )
    }

    /// Debug configuration with verbose formatting
    ///
    /// **Use when**: Debugging persistence issues
    ///
    /// **Features**:
    /// - Pretty printed JSON
    /// - ISO8601 dates
    /// - Sorted keys
    /// - Same as iso8601 but semantically named for debug
    public static var debug: Self {
        .iso8601
    }
}
