//
//  LoadableState.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation

public enum LoadableState: Equatable, CustomDebugStringConvertible,  Sendable {
    public static func == (lhs: LoadableState, rhs: LoadableState) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested):
            return true
        case (.loading, .loading):
            return true
        case (.loaded, .loaded):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }

    case notRequested
    case loading
    case loaded
    case failed(Error)
    
    public var debugDescription: String{
        switch self {
        case .notRequested:
            return ".notRequested"
        case .loading:
            return ".loading"
        case .loaded:
            return ".loaded"
        case .failed:
            return ".failed"
        }
    }
    
    
    public var error: Error? {
        switch self {
        case let .failed(error): return error
        default: return nil
        }
    }

    public func isNotRequested() -> Bool {
        switch self {
        case .notRequested:
            return true
        default:
            return false
        }
    }

    public func isLoaded() -> Bool {
        switch self {
        case .loaded:
            return true
        default:
            return false
        }
    }

    public func isError() -> Bool {
        switch self {
        case .failed:
            return true
        default:
            return false
        }
    }

    public func isLoading() -> Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    // MARK: - State Merging

    /// Merges multiple `LoadableModelSupport` instances into a single `LoadableState`.
    ///
    /// Priority logic:
    /// 1. If all stores are loaded → returns `.loaded`
    /// 2. If any store has an error → returns `.failed(error)` with the first error
    /// 3. If any store is loading → returns `.loading`
    /// 4. Otherwise → returns `.notRequested`
    ///
    /// - Parameter items: Array of `LoadableModelSupport` instances to merge
    /// - Returns: Merged `LoadableState` representing the combined state
    @MainActor
    public static func mergeStates(items: [any LoadableModelSupport]) -> LoadableState {
        guard !items.isEmpty else {
            return .notRequested
        }

        let states = items.map(\.loadState)

        // Check if all are loaded
        let allLoaded = states.allSatisfy { $0.isLoaded() }
        if allLoaded {
            return .loaded
        }

        // Check for any errors (return first error found)
        if let firstError = states.compactMap(\.error).first {
            return .failed(firstError)
        }

        // Check if any are loading
        let anyLoading = states.contains { $0.isLoading() }
        if anyLoading {
            return .loading
        }

        // Default to notRequested
        return .notRequested
    }

    /// Merges multiple `LoadableModelSupport` instances into a single `LoadableState` using variadic parameters.
    ///
    /// Priority logic:
    /// 1. If all stores are loaded → returns `.loaded`
    /// 2. If any store has an error → returns `.failed(error)` with the first error
    /// 3. If any store is loading → returns `.loading`
    /// 4. Otherwise → returns `.notRequested`
    ///
    /// - Parameter stores: Variadic `LoadableModelSupport` instances to merge
    /// - Returns: Merged `LoadableState` representing the combined state
    @MainActor
    public static func mergeStates(_ stores: any LoadableModelSupport...) -> LoadableState {
        mergeStates(items: stores)
    }

}
