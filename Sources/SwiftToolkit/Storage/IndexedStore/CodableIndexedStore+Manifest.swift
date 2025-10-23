//
//  CodableIndexedStore+Manifest.swift
//  SwiftToolkit
//
//  Internal manifest/index structure for CodableIndexedStore
//

import Foundation

// MARK: - Manifest

extension CodableIndexedStore {

    /// Manifest/index file structure for CodableIndexedStore
    ///
    /// **Purpose**: Lightweight index for fast queries without loading all files
    ///
    /// **Storage**: Saved as `<namespace>.json` in store directory
    ///
    /// **Structure**:
    /// ```json
    /// {
    ///   "version": 1,
    ///   "namespace": "PersistedDevice",
    ///   "items": {
    ///     "550e8400-e29b-41d4-a716-446655440000": {
    ///       "id": "550e8400-e29b-41d4-a716-446655440000",
    ///       "filename": "550e8400-e29b-41d4-a716-446655440000.json",
    ///       "createdAt": "2024-01-15T10:30:00Z",
    ///       "updatedAt": "2024-01-15T14:20:00Z"
    ///     }
    ///   }
    /// }
    /// ```
    public struct Manifest: Codable, Sendable {

        /// Manifest format version (for future migrations)
        let version: Int

        /// Namespace identifier (matches store namespace)
        let namespace: String

        /// Item entries indexed by ID
        var items: [String: Entry]

        /// Initialize new manifest
        init(version: Int = 1, namespace: String, items: [String: Entry] = [:]) {
            self.version = version
            self.namespace = namespace
            self.items = items
        }

        /// Empty manifest for new stores
        static func empty(namespace: String) -> Manifest {
            Manifest(namespace: namespace)
        }
    }
}

// MARK: - Manifest Entry

extension CodableIndexedStore.Manifest {

    /// Individual item entry in the manifest
    ///
    /// **Purpose**: Track item metadata without loading full content
    ///
    /// **Properties**:
    /// - `id`: Item identifier (as string for JSON compatibility)
    /// - `filename`: Generated filename in items folder
    /// - `createdAt`: Item creation timestamp
    /// - `updatedAt`: Last modification timestamp
    internal struct Entry: Codable, Sendable, Hashable {

        /// Item identifier (string representation for JSON)
        let id: String

        /// Filename in items folder (generated via closure)
        let filename: String

        /// Creation timestamp
        let createdAt: Date

        /// Last update timestamp
        var updatedAt: Date

        /// Initialize new entry
        init(id: String, filename: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
            self.id = id
            self.filename = filename
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// Update timestamp
        mutating func markUpdated() {
            updatedAt = Date()
        }
    }
}

// MARK: - Manifest Operations

extension CodableIndexedStore.Manifest {

    /// Add or update item in manifest
    mutating func upsert(id: Item.ID, filename: String) {
        let idString = String(describing: id)

        if var existing = items[idString] {
            existing.markUpdated()
            items[idString] = existing
        } else {
            items[idString] = Entry(id: idString, filename: filename)
        }
    }

    /// Remove item from manifest
    @discardableResult
    mutating func remove(id: Item.ID) -> Entry? {
        let idString = String(describing: id)
        return items.removeValue(forKey: idString)
    }

    /// Get entry for ID
    func entry(for id: Item.ID) -> Entry? {
        let idString = String(describing: id)
        return items[idString]
    }

    /// Check if manifest contains ID
    func contains(id: Item.ID) -> Bool {
        let idString = String(describing: id)
        return items[idString] != nil
    }

    /// Get all indexed IDs (for queries)
    var allIDs: [String] {
        Array(items.keys)
    }

    /// Get total count
    var count: Int {
        items.count
    }
}

// MARK: - Manifest Statistics

extension CodableIndexedStore.Manifest {

    /// Manifest statistics
    public struct Statistics: Sendable {
        public let totalItems: Int
        public let oldestCreated: Date?
        public let newestCreated: Date?
        public let oldestUpdated: Date?
        public let newestUpdated: Date?

        public init(
            totalItems: Int,
            oldestCreated: Date? = nil,
            newestCreated: Date? = nil,
            oldestUpdated: Date? = nil,
            newestUpdated: Date? = nil
        ) {
            self.totalItems = totalItems
            self.oldestCreated = oldestCreated
            self.newestCreated = newestCreated
            self.oldestUpdated = oldestUpdated
            self.newestUpdated = newestUpdated
        }
    }

    /// Compute manifest statistics
    func statistics() -> Statistics {
        guard !items.isEmpty else {
            return Statistics(totalItems: 0)
        }

        let entries = items.values
        return Statistics(
            totalItems: items.count,
            oldestCreated: entries.map(\.createdAt).min(),
            newestCreated: entries.map(\.createdAt).max(),
            oldestUpdated: entries.map(\.updatedAt).min(),
            newestUpdated: entries.map(\.updatedAt).max()
        )
    }
}
