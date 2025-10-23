//
//  CodableIndexedStore+Event.swift
//  SwiftToolkit
//
//  Event types for CodableIndexedStore change notifications
//

import Foundation

// MARK: - Store Event

extension CodableIndexedStore {

    /// Events emitted by CodableIndexedStore for observation
    ///
    /// **Purpose**: Real-time notification of store changes
    ///
    /// **Usage**:
    /// ```swift
    /// for await event in store.events {
    ///     switch event {
    ///     case .itemAdded(let id):
    ///         print("New item: \(id)")
    ///     case .itemUpdated(let id):
    ///         print("Updated item: \(id)")
    ///     case .itemRemoved(let id):
    ///         print("Removed item: \(id)")
    ///     case .allItemsRemoved:
    ///         print("Store cleared")
    ///     }
    /// }
    /// ```
    public enum Event: Sendable {

        /// New item was added to store
        case itemAdded(id: Item.ID)

        /// Existing item was updated
        case itemUpdated(id: Item.ID)

        /// Item was removed from store
        case itemRemoved(id: Item.ID)

        /// All items were removed (store cleared)
        case allItemsRemoved

        /// Multiple items were added (bulk operation)
        case itemsAdded(ids: [Item.ID])

        /// Multiple items were removed (bulk operation)
        case itemsRemoved(ids: [Item.ID])
    }
}

// MARK: - Event Convenience Properties

extension CodableIndexedStore.Event {

    /// Affected item ID (if single-item event)
    public var affectedID: Item.ID? {
        switch self {
        case .itemAdded(let id), .itemUpdated(let id), .itemRemoved(let id):
            return id
        case .allItemsRemoved, .itemsAdded, .itemsRemoved:
            return nil
        }
    }

    /// Affected item IDs (all events)
    public var affectedIDs: [Item.ID] {
        switch self {
        case .itemAdded(let id), .itemUpdated(let id), .itemRemoved(let id):
            return [id]
        case .itemsAdded(let ids), .itemsRemoved(let ids):
            return ids
        case .allItemsRemoved:
            return []
        }
    }

    /// Whether event is a mutation (add/update/remove)
    public var isMutation: Bool {
        true  // All events represent mutations
    }

    /// Whether event affects multiple items
    public var isBulkOperation: Bool {
        switch self {
        case .itemsAdded, .itemsRemoved, .allItemsRemoved:
            return true
        case .itemAdded, .itemUpdated, .itemRemoved:
            return false
        }
    }
}

// MARK: - Event CustomStringConvertible

extension CodableIndexedStore.Event: CustomStringConvertible {
    public var description: String {
        switch self {
        case .itemAdded(let id):
            return "CodableIndexedStore.Event.itemAdded(id: \(id))"
        case .itemUpdated(let id):
            return "CodableIndexedStore.Event.itemUpdated(id: \(id))"
        case .itemRemoved(let id):
            return "CodableIndexedStore.Event.itemRemoved(id: \(id))"
        case .allItemsRemoved:
            return "CodableIndexedStore.Event.allItemsRemoved"
        case .itemsAdded(let ids):
            return "CodableIndexedStore.Event.itemsAdded(count: \(ids.count))"
        case .itemsRemoved(let ids):
            return "CodableIndexedStore.Event.itemsRemoved(count: \(ids.count))"
        }
    }
}
