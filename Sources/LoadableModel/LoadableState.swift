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
    
}
