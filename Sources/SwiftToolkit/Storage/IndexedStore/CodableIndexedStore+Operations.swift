//
//  CodableIndexedStore+Operations.swift
//  SwiftToolkit
//
//  CRUD operations and helper methods for CodableIndexedStore
//

import Foundation

// MARK: - CRUD Operations

public extension CodableIndexedStore {
    /// Save item to store (add or update)
    ///
    /// **Behavior**:
    /// - Generates filename via closure
    /// - Validates filename safety
    /// - Saves item to `<namespace>/<filename>`
    /// - Updates manifest and saves to disk
    /// - Emits event (.itemAdded or .itemUpdated)
    ///
    /// **Performance**: ~1-5ms for single item
    ///
    /// **Thread-Safe**: Actor isolation
    @discardableResult
    func save(_ item: Item) async throws -> Item {
        var manifest = try await ensureInitialized()

        if debugSettings.logOperations {
            logger.debug("Saving item: \(item.id)")
        }

        // Generate filename
        let filename = filenameGenerator(item.id)

        // Validate filename safety
        if configuration.validateFilenames {
            try validateFilename(filename, for: item.id)
        }

        // Determine if add or update
        let isUpdate = manifest.contains(id: item.id)

        // Save item file
        let itemURL = itemsDirectory.appendingPathComponent(filename)
        try saveItemFile(item, to: itemURL)

        // Update manifest
        manifest.upsert(id: item.id, filename: filename)
        self.manifest = manifest
        try saveManifest()

        // Update cache
        cache[item.id] = item

        // Emit event
        let event: Event = isUpdate ? .itemUpdated(id: item.id) : .itemAdded(id: item.id)
        emitEvent(event)

        if debugSettings.logOperations {
            logger.debug("Saved item: \(item.id) (\(isUpdate ? "updated" : "added"))")
        }

        return item
    }

    /// Fetch item by ID
    ///
    /// **Performance**: ~1-2ms (cached) or ~3-5ms (from disk)
    ///
    /// **Throws**: `IndexedStoreError.itemNotFound` if not in store
    func fetch(id: Item.ID) async throws -> Item {
        let manifest = try await ensureInitialized()

        // Check cache first
        if let cached = cache[id] {
            return cached
        }

        // Get filename from manifest
        guard let entry = manifest.entry(for: id) else {
            throw IndexedStoreError.itemNotFound(id: String(describing: id))
        }

        // Load from disk
        let itemURL = itemsDirectory.appendingPathComponent(entry.filename)
        let item = try loadItemFile(from: itemURL, id: id)

        // Update cache
        cache[id] = item

        return item
    }

    /// Fetch all items
    ///
    /// **Performance**: O(n) - loads all items from disk if not cached
    ///
    /// **Returns**: Array of all items (order not guaranteed)
    func fetchAll() async throws -> [Item] {
        try await ensureInitialized()

        var items: [Item] = []

        for entry in manifest!.items.values {
            let itemURL = itemsDirectory.appendingPathComponent(entry.filename)

            // Reconstruct ID from entry.id string
            guard let id = reconstructID(from: entry.id) else {
                if debugSettings.logOperations {
                    logger.warning("Could not reconstruct ID from '\(entry.id)'")
                }
                continue
            }

            // Check cache
            if let cached = cache[id] {
                items.append(cached)
            } else {
                let item = try loadItemFile(from: itemURL, id: id)
                cache[id] = item
                items.append(item)
            }
        }

        return items
    }

    /// Remove item by ID
    ///
    /// **Behavior**:
    /// - Removes item file from disk
    /// - Updates manifest and saves
    /// - Clears from cache
    /// - Emits .itemRemoved event
    ///
    /// **Throws**: `IndexedStoreError.itemNotFound` if not in store
    @discardableResult
    func remove(id: Item.ID) async throws -> Item {
        var manifest = try await ensureInitialized()

        guard let entry = manifest.entry(for: id) else {
            throw IndexedStoreError.itemNotFound(id: String(describing: id))
        }

        // Load item before removing (to return it)
        let item = try await fetch(id: id)

        // Remove file
        let itemURL = itemsDirectory.appendingPathComponent(entry.filename)
        try removeItemFile(at: itemURL, id: id)

        // Update manifest
        manifest.remove(id: id)
        self.manifest = manifest
        try saveManifest()

        // Clear cache
        cache.removeValue(forKey: id)

        // Emit event
        emitEvent(.itemRemoved(id: id))

        if debugSettings.logOperations {
            logger.debug("Removed item: \(id)")
        }

        return item
    }

    /// Remove all items
    ///
    /// **Behavior**:
    /// - Deletes all item files
    /// - Clears manifest
    /// - Clears cache
    /// - Emits .allItemsRemoved event
    ///
    /// **Performance**: O(n) where n = item count
    func removeAll() async throws {
        _ = try await ensureInitialized()

        // Remove all item files (only in file mode)
        if configuration.storageMode == .file {
            let itemURLs = try fileManager.contentsOfDirectory(
                at: itemsDirectory,
                includingPropertiesForKeys: nil
            )

            for url in itemURLs where url.pathExtension == "json" {
                try fileManager.removeItem(at: url)
            }
        }

        // Clear manifest
        manifest = Manifest.empty(namespace: namespace)
        try saveManifest()

        // Clear cache
        cache.removeAll()

        // Emit event
        emitEvent(.allItemsRemoved)

        if debugSettings.logOperations {
            logger.debug("Removed all items")
        }
    }
}

// MARK: - Query Operations

public extension CodableIndexedStore {
    /// Check if item exists
    func contains(id: Item.ID) async -> Bool {
        guard let manifest = try? await ensureInitialized() else { return false }
        return manifest.contains(id: id)
    }

    /// Get all item IDs (fast - from manifest)
    var allIDs: [Item.ID] {
        get async {
            guard let manifest = try? await ensureInitialized() else { return [] }
            return manifest.allIDs.compactMap { reconstructID(from: $0) }
        }
    }

    /// Get item count (fast - from manifest)
    var count: Int {
        get async {
            guard let manifest = try? await ensureInitialized() else { return 0 }
            return manifest.count
        }
    }

    /// Get store statistics
    func statistics() async throws -> Manifest.Statistics {
        let manifest = try await ensureInitialized()
        return manifest.statistics()
    }
}

// MARK: - Event Stream

public extension CodableIndexedStore {
    /// Event stream for observing store changes
    ///
    /// **Usage**:
    /// ```swift
    /// for await event in store.events {
    ///     switch event {
    ///     case .itemAdded(let id): print("Added: \(id)")
    ///     case .itemUpdated(let id): print("Updated: \(id)")
    ///     case .itemRemoved(let id): print("Removed: \(id)")
    ///     case .allItemsRemoved: print("Cleared")
    ///     }
    /// }
    /// ```
    var events: AsyncStream<Event> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
}

// MARK: - Private Helpers - File Operations

extension CodableIndexedStore {
    private func saveItemFile(_ item: Item, to url: URL) throws {
        // Skip disk I/O in memory mode
        guard configuration.storageMode == .file else { return }

        do {
            let data = try encoder.encode(item)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw IndexedStoreError.itemSaveFailed(
                id: String(describing: item.id),
                filename: url.lastPathComponent,
                underlying: error
            )
        }
    }

    private func loadItemFile(from url: URL, id: Item.ID) throws -> Item {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw IndexedStoreError.itemLoadFailed(
                id: String(describing: id),
                filename: url.lastPathComponent,
                underlying: error
            )
        }
    }

    private func removeItemFile(at url: URL, id: Item.ID) throws {
        // Skip disk I/O in memory mode
        guard configuration.storageMode == .file else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw IndexedStoreError.itemDeleteFailed(
                id: String(describing: id),
                filename: url.lastPathComponent,
                underlying: error
            )
        }
    }

    private func saveManifest() throws {
        // Skip disk I/O in memory mode
        guard configuration.storageMode == .file else { return }

        do {
            let data = try encoder.encode(manifest)
            try data.write(to: manifestURL, options: [.atomic])
        } catch {
            throw IndexedStoreError.indexSaveFailed(path: manifestURL.path, underlying: error)
        }
    }
}

// MARK: - Private Helpers - Validation

extension CodableIndexedStore {
    private func validateFilename(_ filename: String, for id: Item.ID) throws {
        guard filename.isSafeFilename() else {
            throw IndexedStoreError.unsafeFilename(
                id: String(describing: id),
                filename: filename,
                reason: "Contains unsafe characters or path traversal"
            )
        }

        guard !filename.isEmpty else {
            throw IndexedStoreError.unsafeFilename(
                id: String(describing: id),
                filename: filename,
                reason: "Filename is empty"
            )
        }
    }
}

// MARK: - Private Helpers - ID Reconstruction

extension CodableIndexedStore {
    /// Reconstruct typed ID from string representation
    ///
    /// **Note**: This is a simplification. In production, you might need a more
    /// sophisticated approach for complex ID types.
    private func reconstructID(from string: String) -> Item.ID? {
        // For UUID IDs
        if Item.ID.self == UUID.self {
            return UUID(uuidString: string) as? Item.ID
        }

        // For String IDs
        if Item.ID.self == String.self {
            return string as? Item.ID
        }

        // For other types, try converting via String description
        // This is a limitation - consider making ID: LosslessStringConvertible
        return nil
    }
}

// MARK: - Private Helpers - Events

extension CodableIndexedStore {
    private func emitEvent(_ event: Event) {
        eventContinuation?.yield(event)
    }
}

// MARK: - Static Helpers

extension CodableIndexedStore {
    static func createDirectoryStructure(
        directory: URL,
        namespace: String,
        fileManager: FileManager
    ) throws {
        // Create base directory
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                throw IndexedStoreError.directoryCreationFailed(path: directory.path, underlying: error)
            }
        }

        // Create namespace folder
        let itemsDir = directory.appendingPathComponent(namespace)
        if !fileManager.fileExists(atPath: itemsDir.path) {
            do {
                try fileManager.createDirectory(at: itemsDir, withIntermediateDirectories: false)
            } catch {
                throw IndexedStoreError.namespaceFolderCreationFailed(namespace: namespace, underlying: error)
            }
        }
    }

    static func loadOrCreateManifest(
        at url: URL,
        namespace: String,
        fileManager: FileManager,
        decoder: JSONDecoder,
        recreateOnDecodingError: Bool,
        logger: LoggerWrapper?
    ) throws -> Manifest {
        guard fileManager.fileExists(atPath: url.path) else {
            // Create new empty manifest
            return .empty(namespace: namespace)
        }

        // Load existing manifest
        do {
            let data = try Data(contentsOf: url)
            let manifest = try decoder.decode(Manifest.self, from: data)

            // Validate namespace matches
            guard manifest.namespace == namespace else {
                throw IndexedStoreError.namespaceMismatch(expected: namespace, found: manifest.namespace)
            }

            return manifest
        } catch {
            // Check if we should recreate on decoding error
            if recreateOnDecodingError {
                logger?.warning("Manifest decoding failed, recreating store (recreateOnDecodingError=true)")

                // Delete manifest file
                try? fileManager.removeItem(at: url)

                // Delete all items in namespace folder
                let itemsDirectory = url.deletingLastPathComponent().appendingPathComponent(namespace)
                if fileManager.fileExists(atPath: itemsDirectory.path) {
                    try? fileManager.removeItem(at: itemsDirectory)

                    // Recreate empty items directory
                    try? fileManager.createDirectory(at: itemsDirectory, withIntermediateDirectories: false)
                }

                logger?.info("Store recreated with empty manifest for namespace '\(namespace)'")

                // Return new empty manifest
                return .empty(namespace: namespace)
            } else {
                // Normal error handling - throw
                throw IndexedStoreError.indexLoadFailed(path: url.path, underlying: error)
            }
        }
    }
}
