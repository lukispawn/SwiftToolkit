//
//  LoadableCollectionProvider.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation

/// Protocol for providing collection data to a LoadableCollectionStore.
///
/// Implement this protocol to create custom data sources for collections with
/// support for pagination, queries, and cursor-based loading.
///
/// **Example:**
/// ```swift
/// struct ProductsProvider: LoadableCollectionProvider {
///     typealias Model = Product
///     typealias Cursor = String
///     typealias Query = ProductFilter
///
///     func load(query: ProductFilter?) async throws -> LoadableCollectionResult<Product, String> {
///         let (products, nextCursor) = try await apiClient.fetchProducts(filter: query)
///         return LoadableCollectionResult(
///             data: products,
///             nextCursor: nextCursor,
///             previousCursor: nil,
///             allCount: nil
///         )
///     }
/// }
/// ```
public protocol LoadableCollectionProvider<Model, Cursor, Query>: Sendable {
    /// The type of items in the collection.
    associatedtype Model: Identifiable

    /// The type used for pagination cursors.
    associatedtype Cursor: Equatable

    /// The type used for filtering/querying the collection.
    associatedtype Query: Equatable

    /// Called before loading to optionally provide cached data or proceed with load.
    ///
    /// Return `.provide(result)` to skip loading and use provided data.
    /// Return `.proceed` to continue with normal loading.
    ///
    /// - Parameters:
    ///   - previous: The previous data status
    ///   - query: The query being used for this load
    /// - Returns: Disposition indicating whether to proceed or provide data
    func willLoad(
        previous: LoadedCollectionStatus<[Model], Cursor, Query>,
        query: Query?
    ) async -> RefreshDisposition<LoadableCollectionResult<Model, Cursor>>

    /// Fetches the initial collection data for the given query.
    ///
    /// - Parameter query: Optional query to filter/search the collection
    /// - Returns: Collection result with data and pagination cursors
    /// - Throws: Any error that occurred during loading
    func load(
        query: Query?
    ) async throws -> LoadableCollectionResult<Model, Cursor>

    /// Checks if a next page is available for the given cursor.
    ///
    /// - Parameter cursor: The cursor to check
    /// - Returns: true if a next page can be loaded
    func nextPageAvailable(
        _ cursor: Cursor?
    ) -> Bool

    /// Checks if a previous page is available for the given cursor.
    ///
    /// - Parameter cursor: The cursor to check
    /// - Returns: true if a previous page can be loaded
    func previousPageAvailable(
        _ cursor: Cursor?
    ) -> Bool

    /// Loads a specific page using a cursor.
    ///
    /// - Parameters:
    ///   - cursor: The cursor identifying the page to load
    ///   - type: The type of page (.next or .previous)
    /// - Returns: Collection result with the page data
    /// - Throws: Any error that occurred during loading
    func loadCursor(
        _ cursor: Cursor,
        type: LoadableArrayPageCursorType
    ) async throws -> LoadableCollectionResult<Model, Cursor>

    /// Optionally provides custom logic for merging cursor results with existing data.
    ///
    /// Return nil to use default merge behavior (append for .next, prepend for .previous).
    ///
    /// - Parameters:
    ///   - cursor: The cursor type that was loaded
    ///   - existing: The existing items in the collection
    ///   - append: The new items to merge
    /// - Returns: The merged collection, or nil to use default merge
    func mergeFromCursor(
        cursor: LoadableArrayPageCursorType,
        existing: [Model],
        append: [Model],
    ) -> [Model]?

    /// Specifies which cursors should be preserved after initial fetch.
    ///
    /// Return page types whose cursors should NOT be updated by the fetch result.
    ///
    /// - Returns: Array of cursor types to preserve
    func overridePageCursorAfterInitialFetch() -> [LoadableArrayPageCursorType]

    /// Specifies which cursors should be preserved after page fetch.
    ///
    /// Return page types whose cursors should NOT be updated by the fetch result.
    ///
    /// - Parameter loadType: The type of page that was just loaded
    /// - Returns: Array of cursor types to preserve
    func overridePageCursorAfterPageFetch(
        loadType: LoadableArrayPageCursorType
    ) -> [LoadableArrayPageCursorType]

    /// Processes/transforms collection content after loading.
    ///
    /// Use this to apply transformations, filtering, or sorting to the loaded data.
    ///
    /// - Parameter content: The raw loaded content
    /// - Returns: The processed content
    /// - Throws: Any error that occurred during processing
    func processContent(
        _ content: [Model]
    ) async throws -> [Model]
}

public extension LoadableCollectionProvider {
    func willLoad(
        previous: LoadedCollectionStatus<[Model], Cursor, Query>,
        query: Query?
    ) async -> RefreshDisposition<LoadableCollectionResult<Model, Cursor>> {
        return .proceed
    }
    
    func load(
        query: Query?
    ) async throws -> LoadableCollectionResult<Model, Cursor> {
        throw LoadableError.notSupported("load()")
    }

    func loadCursor(
        _ cursor: Cursor,
        type: LoadableArrayPageCursorType
    ) async throws -> LoadableCollectionResult<Model, Cursor> {
        throw LoadableError.notSupported("loadNext(cursor:)")
    }
    func mergeFromCursor(
        cursor: LoadableArrayPageCursorType,
        existing: [Model],
        append: [Model],
    ) -> [Model]? { nil }
    
    func overridePageCursorAfterPageFetch(loadType: LoadableArrayPageCursorType) -> [LoadableArrayPageCursorType] { [] }
    
    func overridePageCursorAfterInitialFetch() -> [LoadableArrayPageCursorType] { [] }
   
    func processContent(
        _ content: [Model]
    ) async throws -> [Model] {
        content
    }

    func nextPageAvailable(
        _ cursor: Cursor?
    ) -> Bool {
        cursor != nil
    }
    
    func previousPageAvailable(
        _ cursor: Cursor?
    ) -> Bool {
        cursor != nil
    }

}

/// Result type returned by collection providers containing data and pagination info.
public struct LoadableCollectionResult<T: Identifiable, Cursor: Equatable>: @unchecked Sendable {
    /// The loaded collection items.
    public let data: [T]

    /// Optional cursor for loading the next page.
    let nextCursor: Cursor?

    /// Optional cursor for loading the previous page.
    let previousCursor: Cursor?

    /// Optional total count of all items (across all pages).
    let allCount: Int?

    /// Optional additional metadata (not type-safe).
    let info: Any?

    public init(data: [T], nextCursor: Cursor?, previousCursor: Cursor?, allCount: Int?, info: Any? = nil) {
        self.data = data
        self.nextCursor = nextCursor
        self.previousCursor = previousCursor
        self.allCount = allCount
        self.info = info
    }
}
