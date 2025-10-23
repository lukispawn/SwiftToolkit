//
//  FilenameGenerators.swift
//  SwiftToolkit
//
//  Common filename generation strategies for CodableIndexedStore
//

import Foundation
import CryptoKit

/// Common filename generation strategies
///
/// **Usage**:
/// ```swift
/// let store = try await CodableIndexedStore<PersistedDevice>(
///     directory: .documents,
///     namespace: "Devices",
///     filename: FilenameGenerator.uuid
/// )
/// ```
public enum FilenameGenerator {

    /// Generate filename from UUID identifier
    ///
    /// **Format**: `"550e8400-e29b-41d4-a716-446655440000.json"`
    ///
    /// **Use when**: ID type is UUID
    ///
    /// **Safety**: UUID strings are inherently safe filenames
    public static func uuidFilename(for id: UUID) -> String {
        "\(id.uuidString).json"
    }

    /// Generate filename from UUID identifier (closure version)
    ///
    /// **Format**: `"550e8400-e29b-41d4-a716-446655440000.json"`
    ///
    /// **Use when**: ID type is UUID, need type-erased closure
    ///
    /// **Safety**: UUID strings are inherently safe filenames
    public static let uuid: @Sendable (UUID) -> String = { id in
        "\(id.uuidString).json"
    }

    /// Generate sanitized filename from String identifier
    ///
    /// **Format**: `"<sanitized-string>.json"`
    ///
    /// **Use when**: ID type is String
    ///
    /// **Safety**: Applies full sanitization (path traversal, null bytes, reserved names, etc.)
    ///
    /// **Fallback**: Uses SHA256 hash if sanitization results in empty string
    public static let safeString: @Sendable (String) -> String = { id in
        let safe = id.makeSafeFilename()
        return safe.isEmpty ? sha256Hash(id) : "\(safe).json"
    }

    /// Generate SHA256 hash-based filename from any identifier
    ///
    /// **Format**: `"a1b2c3d4e5f6...json"`
    ///
    /// **Use when**:
    /// - ID type has complex description
    /// - Want deterministic filename from any input
    /// - Maximum safety for untrusted IDs
    ///
    /// **Safety**: Hash output is always safe filename (hex characters only)
    ///
    /// **Trade-off**: Not human-readable
    public static func sha256Hash<ID>(_ id: ID) -> String {
        let description = String(describing: id)
        let data = Data(description.utf8)
        let hash = SHA256.hash(data: data)
        return "\(hash.compactMap { String(format: "%02x", $0) }.joined()).json"
    }

    /// Generate SHA256 hash-based filename (closure version)
    public static let sha256: @Sendable (any CustomStringConvertible & Sendable) -> String = { id in
        sha256Hash(id)
    }

    /// Generate prefixed filename with sanitized ID
    ///
    /// **Format**: `"<prefix>-<sanitized-id>.json"`
    ///
    /// **Use when**: Need namespace prefix within files
    ///
    /// **Example**:
    /// ```swift
    /// filename: FilenameGenerator.prefixed("device")
    /// // "device-550e8400.json"
    /// ```
    public static func prefixed(_ prefix: String) -> @Sendable (String) -> String {
        return { id in
            let safe = id.makeSafeFilename()
            let finalId = safe.isEmpty ? sha256Hash(id) : safe
            return "\(prefix)-\(finalId).json"
        }
    }

    /// Generate timestamped filename with sanitized ID
    ///
    /// **Format**: `"<sanitized-id>-<timestamp>.json"`
    ///
    /// **Use when**: Need temporal versioning
    ///
    /// **Warning**: Creates new file on every save (not suitable for updates)
    public static func timestamped<ID>(_ id: ID) -> String {
        let description = String(describing: id)
        let safe = description.makeSafeFilename()
        let finalId = safe.isEmpty ? sha256Hash(id) : safe
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(finalId)-\(timestamp).json"
    }
}
