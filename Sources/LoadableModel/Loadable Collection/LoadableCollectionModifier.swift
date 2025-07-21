//
//  LoadableCollectionModifier.swift
//  LoadableModel
//
//  Created by LoadableModel on 23/12/2024.
//

import Foundation

/// Protocol for modifying items in a loadable collection
/// Separate from LoadableCollectionProvider to follow Single Responsibility Principle
public protocol LoadableCollectionModifier<Model>: Sendable {
    associatedtype Model: Identifiable
    
    /// Refresh a specific item by ID, typically by re-fetching from server
    func refreshItem(
        _ objectId: Model.ID
    ) async throws -> Model
    
    /// Remove an item by ID, typically by deleting from server
    func removeItem(
        _ objectId: Model.ID
    ) async throws
    
}


