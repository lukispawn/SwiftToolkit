//
//  CodableIndexedStore+Factory.swift
//  SwiftToolkit
//
//  Factory methods for common ID types
//

import Foundation

// MARK: - Factory Methods

extension CodableIndexedStore where Item.ID == UUID {

    /// Create store with UUID-based filenames (lazy loading)
    ///
    /// **Convenience** for UUID-based stores (most common case)
    ///
    /// **Filename Pattern**: `{uuid}.json`
    ///
    /// **Note**: Directory creation and manifest loading happen on first operation (lazy)
    ///
    /// **Example**:
    /// ```swift
    /// let store = CodableIndexedStore<User>.create(
    ///     directory: .documentsDirectory,
    ///     namespace: "users"
    /// )
    /// ```
    public static func create(
        directory: URL,
        namespace: String,
        configuration: Configuration = Configuration(),
        debugSettings: DebugSettings = DebugSettings()
    ) -> CodableIndexedStore<Item> {
        CodableIndexedStore<Item>(
            directory: directory,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: configuration,
            debugSettings: debugSettings
        )
    }

    /// Create store with LocalFileURL.Directory and UUID-based filenames (lazy loading)
    ///
    /// **Convenience** for UUID-based stores with Directory objects
    ///
    /// **Filename Pattern**: `{uuid}.json`
    ///
    /// **Note**: Directory creation and manifest loading happen on first operation (lazy)
    ///
    /// **Example**:
    /// ```swift
    /// let store = CodableIndexedStore<User>.create(
    ///     directory: fileLocation.directory,
    ///     namespace: "users"
    /// )
    /// ```
    public static func create(
        directory: LocalFileURL.Directory,
        namespace: String,
        configuration: Configuration = Configuration(),
        debugSettings: DebugSettings = DebugSettings()
    ) -> CodableIndexedStore<Item> {
        CodableIndexedStore<Item>(
            directory: directory,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: configuration,
            debugSettings: debugSettings
        )
    }
}
