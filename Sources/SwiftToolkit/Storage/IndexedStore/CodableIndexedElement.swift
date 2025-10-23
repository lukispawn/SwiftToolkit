//
//  CodableIndexedElement.swift
//  SwiftToolkit
//
//  Protocol for items that can be stored in CodableIndexedStore
//

import Foundation

/// Protocol for items that can be stored in CodableIndexedStore
///
/// **Requirements**:
/// - `Codable` - JSON serialization support
/// - `Identifiable` - Unique identification for indexing
/// - `Hashable` - Dictionary keys and efficient caching
/// - `ID: Codable & Sendable` - ID must be serializable and thread-safe
///
/// **Design Philosophy**:
/// - Clean and simple - no additional requirements
/// - Filename generation provided via closure at store initialization
/// - No coupling between domain models and storage implementation
///
/// **Example**:
/// ```swift
/// struct User: CodableIndexedElement {
///     let id: UUID
///     let name: String
///     let email: String
/// }
/// ```
public protocol CodableIndexedElement: Codable, Identifiable, Hashable where ID: Codable & Sendable {
    // Clean protocol - filename logic provided externally via closure
}
