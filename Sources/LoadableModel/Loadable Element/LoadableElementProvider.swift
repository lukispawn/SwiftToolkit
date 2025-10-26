//
//  LoadableElementProvider.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation



/// Protocol for providing data to a LoadableElementStore.
///
/// Implement this protocol to create custom data sources for single elements.
/// The store will call these methods to fetch and validate data.
///
/// **Example:**
/// ```swift
/// struct UserProvider: LoadableElementProvider {
///     let userId: String
///
///     func load() async throws -> User {
///         try await apiClient.fetchUser(userId)
///     }
/// }
/// ```
public protocol LoadableElementProvider<Model>: Sendable {

    /// Called before loading to optionally provide cached data or proceed with load.
    ///
    /// Return `.provide(result)` to skip loading and use provided data.
    /// Return `.proceed` to continue with normal loading.
    ///
    /// - Parameter previous: The previous data status
    /// - Returns: Disposition indicating whether to proceed or provide data
    func willLoad(previous: LoadedElementStatus<Model>) async -> RefreshDisposition<Model>

    associatedtype Model

    /// Fetches the data from the source.
    ///
    /// This is the main method that performs the actual data loading.
    ///
    /// - Returns: The loaded data
    /// - Throws: Any error that occurred during loading
    func load() async throws -> Model
}

public extension LoadableElementProvider {
    func load() async throws -> Model {
        throw LoadableError.notSupported("load()")
    }
    func willLoad(previous: LoadedElementStatus<Model>) async -> RefreshDisposition<Model> {
        return .proceed
    }
    
}

/// Errors that can occur in loadable operations.
public enum LoadableError: Error, LocalizedError {
    /// The requested operation is not supported by this provider or modifier.
    case notSupported(String)

    /// No service was configured for the operation.
    case serviceNotSet

    /// An internal error occurred.
    case internalError

    public var errorDescription: String? {
        switch self {
        case .notSupported(let message):
            return "Not implemented yet. \(message)"
        case .serviceNotSet:
            return "Service not set"
        case .internalError:
            return "Internal error"
        }
    }
}



