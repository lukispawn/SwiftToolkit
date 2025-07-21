//
//  Loadable.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation
import SwiftUI

public enum LoadedElementStatus<T: Sendable>: Sendable, CustomDebugStringConvertible {
    
    
    case notRequested
    case isLoading(last: T?)
    case loaded(T)
    case failed(Error)

    public var state: LoadableState {
        switch self {
        case .notRequested:
            return .notRequested
        case let .isLoading(last):
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
    
    public var debugDescription: String {
        debugStatus
    }

    public var debugStatus: String {
        switch self {
        case .failed: return ".failed"
        case .notRequested: return ".notRequested"
        case let .isLoading(last):
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
        switch self {
        case let .loaded(value): return value
        case let .isLoading(last): return last
        default: return nil
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
        case .isLoading:
            return true
        default:
            return false
        }
    }
}

public extension LoadedElementStatus {
    mutating func setIsLoading(resetLast: Bool = false) {
        let lastValue = resetLast ? nil : value
        self = .isLoading(last: lastValue)
    }

    /*
    mutating func cancelLoading(updateState: Bool = true) {
        switch self {
        case let .isLoading(last, cancelBag):
            cancelBag.cancel()
            if updateState {
                if let last = last {
                    self = .loaded(last)
                } else {
                    let error = NSError(
                        domain: NSCocoaErrorDomain, code: NSUserCancelledError,
                        userInfo: [
                            NSLocalizedDescriptionKey: NSLocalizedString("Canceled by user", comment: "")
                        ]
                    )
                    self = .failed(error)
                }
            }
        default: break
        }
    }
    */
    
    func map<V>(_ transform: (T) throws -> V) -> LoadedElementStatus<V> {
        do {
            switch self {
            case .notRequested: return .notRequested
            case let .failed(error): return .failed(error)
            case let .isLoading(value):
                return .isLoading(last: try value.map { try transform($0) })
            case let .loaded(value):
                return .loaded(try transform(value))
            }
        } catch {
            return .failed(error)
        }
    }

    mutating func set(newValue: T) {
        switch self {
        case .isLoading:
            self = .loaded(newValue)
        case .loaded:
            self = .loaded(newValue)
        case .failed, .notRequested:
            self = .loaded(newValue)
        }
    }
}

extension LoadedElementStatus: Equatable where T: Equatable {
    public static func == (lhs: LoadedElementStatus<T>, rhs: LoadedElementStatus<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested): return true
        case let (.isLoading(lhsV), .isLoading(rhsV)): return lhsV == rhsV
        case let (.loaded(lhsV), .loaded(rhsV)): return lhsV == rhsV
        case let (.failed(lhsE), .failed(rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}



