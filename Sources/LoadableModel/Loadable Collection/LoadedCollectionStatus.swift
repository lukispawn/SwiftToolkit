//
//  LoadedCollectionStatus.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Combine
import Foundation
import SwiftUI

public struct LoadableCollectionInfo<T, Cursor: Equatable, Query: Equatable>: @unchecked Sendable {
    
    public let value: T
    public let query: Query?
    public let nextCursor: Cursor?
    public let previousCursor: Cursor?
    public let allCount: Int?
    public let info: Any?

    public var filterHandler: (([T])->[T])?

    public init(
        value: T,
        query: Query?,
        nextCursor: Cursor? = nil,
        previousCursor: Cursor? = nil,
        allCount: Int? = nil,
        info: Any? = nil,
        filterHandler: (([T])->[T])? = nil
    ) {
        self.value = value
        self.query = query
        self.nextCursor = nextCursor
        self.previousCursor = previousCursor
        self.allCount = allCount
        self.info = info
        self.filterHandler = filterHandler
    }
}

public enum LoadableArrayPageCursorType: Equatable, Sendable{
    case next
    case previous
}

public enum LoadedCollectionStatus<T: Sendable, Cursor: Equatable & Sendable, Query: Equatable & Sendable>:  Sendable {

    public struct LoadingPageInfo: Sendable {
        let cursor: Cursor
        let type: LoadableArrayPageCursorType
    }
    
    case notRequested
    case isLoading(last: LoadableCollectionInfo<T, Cursor, Query>?, cursor: LoadingPageInfo?, query:Query?)
    case loaded(LoadableCollectionInfo<T, Cursor, Query>)
    case failed(Error)

    public var debugStatus: String {
        switch self {
        case .failed: return ".failed"
        case .notRequested: return ".notRequested"
        case let .isLoading(last, _, _):
            if last != nil {
                return ".reloading"
            } else {
                return ".loading"
            }
        case .loaded:
            return ".loaded"
        }
    }
    
    public var value: T? {
        return loadedData?.value
    }

    public var state: LoadableState {
        switch self {
        case .notRequested:
            return .notRequested
        case let .isLoading(last, _, _):
            if let _ = last {
                return .loaded
            } else {
                return .loading
            }
        case .loaded:
            return .loaded
        case let .failed(error):
            return .failed(error)
        }
    }

    public var query: Query? {
        switch self {
        case let .loaded(info): return info.query
        case let .isLoading(last,_, loadingQuery): return loadingQuery ?? last?.query
        default: return nil
        }
    }
    
    public var loadedData: LoadableCollectionInfo<T, Cursor, Query>? {
        switch self {
        case let .loaded(info): return info
        case let .isLoading(last, _, _): return last
        default: return nil
        }
    }

    public var latestInfo: Any? {
        switch self {
        case let .loaded(info): return info.info
        case let .isLoading(last, _, _): return last?.info
        default: return nil
        }
    }

    public var error: Error? {
        switch self {
        case let .failed(error): return error
        default: return nil
        }
    }

    public func isLoading()->Bool {
        switch self {
        case .isLoading: return true
        default: return false
        }
    }

    public func isError()->Bool {
        switch self {
        case .failed: return true
        default: return false
        }
    }

    public func isLoaded()->Bool {
        switch self {
        case .loaded: return true
        default: return false
        }
    }

    public func isNotRequested()->Bool {
        switch self {
        case .notRequested:
            return true
        default:
            return false
        }
    }

    public func isLoadingNext()->Bool {
        guard let next = self.nextCursor() else { return false }
        return isLoadingCursor(next)
    }
    
    public func isLoadingPrevious()-> Bool {
        guard let next = self.previousCursor() else { return false }
        return isLoadingCursor(next)
    }
    
    public func nextCursor()->Cursor? {
        return loadedData?.nextCursor
    }
   
    public func previousCursor()->Cursor? {
        return loadedData?.previousCursor
    }

    public func isLoadingCursor(_ cursor: Cursor)->Bool {
        switch self {
        case let .isLoading(_, currentLoading,_) where currentLoading?.cursor == cursor: return true
        default: return false
        }
    }
    
    mutating func delete(at indexSet: IndexSet) {
        switch self {
        case let .isLoading(last, nextCursor, query):
            if let data = last, var newArray = last?.value as? [Any] {
                newArray.remove(atOffsets: indexSet)
                let updateData = LoadableCollectionInfo<T, Cursor, Query>(value: newArray as! T, query: query, nextCursor: data.nextCursor, previousCursor: data.previousCursor, allCount: newArray.count, info: data.info)
                self = .isLoading(last: updateData, cursor: nextCursor,query:query)
            }
        case let .loaded(data):
            if var newArray = data.value as? [Any] {
                newArray.remove(atOffsets: indexSet)
                let updateData = LoadableCollectionInfo<T, Cursor, Query>(value: newArray as! T, query: data.query, nextCursor: data.nextCursor, previousCursor: data.previousCursor, allCount: newArray.count, info: data.info)
                self = .loaded(updateData)
            }
        default:
            break
        }
    }

    @discardableResult
    mutating func set(newValue: T, switchToLoaded: Bool = true) -> LoadableCollectionInfo<T, Cursor, Query> {
        switch self {
        case let .isLoading(last, cursor, query):
            if let data = last {
                let count = (newValue as? [Any])?.count ?? 0
                let updateData = LoadableCollectionInfo<T, Cursor, Query>(value: newValue, query: data.query ?? query, nextCursor: data.nextCursor, previousCursor: data.previousCursor, allCount: count, info: data.info)
                if switchToLoaded {
                    self = .loaded(updateData)
                } else {
                    self = .isLoading(last: updateData, cursor: cursor, query:query)
                }
                return updateData
            } else {
                let count = (newValue as? [Any])?.count ?? 0
                let updateData = LoadableCollectionInfo<T, Cursor, Query>(
                    value: newValue,
                    query: query,
                    nextCursor: nil,
                    previousCursor: nil,
                    allCount: count,
                    info: nil
                )
                self = .loaded(updateData)
                return updateData
            }
        case let .loaded(data):
            let count = (newValue as? [Any])?.count ?? 0
            let updateData: LoadableCollectionInfo<T, Cursor, Query> = .init(value: newValue, query: data.query, nextCursor: data.nextCursor, previousCursor: data.previousCursor, allCount: count, info: data.info)
            self = .loaded(updateData)
            return updateData
        case .failed, .notRequested:
            let count = (newValue as? [Any])?.count ?? 0
            let updateData: LoadableCollectionInfo<T, Cursor, Query> = .init(value: newValue, query: nil, nextCursor: nil, previousCursor: nil, allCount: count)
            self = .loaded(updateData)
            return updateData
        }
    }
}

public extension LoadedCollectionStatus {
    mutating func setIsLoading(cursor: LoadingPageInfo?, query: Query?, resetLast: Bool = false) {
        let lastValue = resetLast ? nil :loadedData
        self = .isLoading(last: lastValue, cursor: cursor, query: query)
    }

    internal func map<V>(_ transform: (T) throws->V)->LoadedCollectionStatus<V, Cursor, Query> {
        do {
            switch self {
            case .notRequested: return .notRequested
            case let .failed(error): return .failed(error)
            case let .isLoading(value, cursor, query):

                let cursorMapped: LoadedCollectionStatus<V, Cursor, Query>.LoadingPageInfo?
                if let cursor{
                    cursorMapped = .init(cursor: cursor.cursor, type: cursor.type)
                }else{
                    cursorMapped = nil
                }
                
                if let value = value {
                    let mapped = try transform(value.value)
                    let info = LoadableCollectionInfo<V, Cursor, Query>(value: mapped, query: value.query ?? query, nextCursor: value.nextCursor, previousCursor: value.previousCursor, allCount: value.allCount)
                    return .isLoading(last: info, cursor: cursorMapped, query: query)

                } else {
                    return .isLoading(last: nil, cursor: cursorMapped,query: query )
                }

            case let .loaded(value):

                let mapped = try transform(value.value)
                let info = LoadableCollectionInfo<V, Cursor, Query>(value: mapped, query: value.query, nextCursor: value.nextCursor, previousCursor: value.previousCursor, allCount: value.allCount)
                return .loaded(info)
            }
        } catch {
            return .failed(error)
        }
    }
}

extension LoadedCollectionStatus: Equatable where T: Equatable {
    public static func == (lhs: LoadedCollectionStatus<T, Cursor, Query>, rhs: LoadedCollectionStatus<T, Cursor, Query>)->Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested): return true
        case let (.isLoading(lhsV, lhsC, lhsQuery), .isLoading(rhsV, rhsC, rhsQuery)): return (lhsV?.value == rhsV?.value) && (lhsC?.cursor == rhsC?.cursor) && (lhsQuery == rhsQuery)
        case let (.loaded(lhsV), .loaded(rhsV)): return lhsV.value == rhsV.value
        case let (.failed(lhsE), .failed(rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}
