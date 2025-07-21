//
//  LoadableCollectionProvider.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation



public protocol LoadableCollectionProvider<Model, Cursor, Query>: Sendable {
    associatedtype Model: Identifiable
    associatedtype Cursor: Equatable
    associatedtype Query: Equatable
    
    func willLoad(
        previous: LoadedCollectionStatus<[Model], Cursor, Query>,
        query: Query?
    ) async -> RefreshDisposition<LoadableCollectionResult<Model, Cursor>>
    
    func load(
        query: Query?
    ) async throws -> LoadableCollectionResult<Model, Cursor>
    
    func nextPageAvailable(
        _ cursor: Cursor?
    ) -> Bool
    
    func previousPageAvailable(
        _ cursor: Cursor?
    ) -> Bool
    
    func loadCursor(
        _ cursor: Cursor,
        type: LoadableArrayPageCursorType
    ) async throws -> LoadableCollectionResult<Model, Cursor>
    
    
    func mergeFromCursor(
        cursor: LoadableArrayPageCursorType,
        existing: [Model],
        append: [Model],
    ) -> [Model]?
    
    func overridePageCursorAfterInitialFetch() -> [LoadableArrayPageCursorType]
    
    func overridePageCursorAfterPageFetch(
        loadType: LoadableArrayPageCursorType
    ) -> [LoadableArrayPageCursorType]
    
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

public struct LoadableCollectionResult<T: Identifiable, Cursor: Equatable>: @unchecked Sendable {
    public let data: [T]
    let nextCursor: Cursor?
    let previousCursor: Cursor?
    let allCount: Int?
    let info: Any?

    public init(data: [T], nextCursor: Cursor?, previousCursor: Cursor?, allCount: Int?, info: Any? = nil) {
        self.data = data
        self.nextCursor = nextCursor
        self.previousCursor = previousCursor
        self.allCount = allCount
        self.info = info
    }
}
