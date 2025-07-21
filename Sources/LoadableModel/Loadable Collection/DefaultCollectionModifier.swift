//
//  DefaultCollectionModifier.swift
//  LoadableModel
//
//  Created by LoadableModel on 23/12/2024.
//

import Foundation

/// Default implementation of LoadableCollectionModifier with block-based handlers
/// Allows you to provide custom logic for modifying collection items
public struct DefaultCollectionModifier<Model: Identifiable & Sendable>: LoadableCollectionModifier, @unchecked Sendable {
    
    public typealias RefreshItemHandler = @Sendable (Model.ID) async throws -> Model
    public typealias RemoveItemHandler = @Sendable (Model.ID) async throws -> Void
    
    private let refreshItemHandler: RefreshItemHandler?
    private let removeItemHandler: RemoveItemHandler?
    
    // MARK: - Initializers
    
    /// Create a modifier with both refresh and remove handlers
    public init(
        refreshItem: RefreshItemHandler? = nil,
        removeItem: RemoveItemHandler? = nil
    ) {
        self.refreshItemHandler = refreshItem
        self.removeItemHandler = removeItem
    }
    
    
    
    // MARK: - LoadableCollectionModifier Implementation
    
    public func refreshItem(_ objectId: Model.ID) async throws -> Model {
        guard let refreshItemHandler else {
            throw LoadableError.notSupported("refreshItem(_:) - no refresh handler provided")
        }
        return try await refreshItemHandler(objectId)
    }
    
    public func removeItem(_ objectId: Model.ID) async throws {
        guard let removeItemHandler else {
            throw LoadableError.notSupported("removeItem(_:) - no remove handler provided")
        }
        try await removeItemHandler(objectId)
    }
}

// MARK: - Convenience Factory Methods

public extension DefaultCollectionModifier {
    /// Create a modifier that always throws "not supported" errors (useful for testing)
    static func notSupported() -> DefaultCollectionModifier<Model> {
        return DefaultCollectionModifier<Model>()
    }
    
    /// Create a modifier with constant error responses
    static func constantError(_ error: Error) -> DefaultCollectionModifier<Model> {
        return DefaultCollectionModifier<Model>(
            refreshItem: { _ in throw error },
            removeItem: { _ in throw error }
        )
    }
    
}
