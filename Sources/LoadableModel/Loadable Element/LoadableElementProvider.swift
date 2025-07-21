//
//  LoadableElementProvider.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Foundation



public protocol LoadableElementProvider<Model>: Sendable {
    
    func willLoad(previous: LoadedElementStatus<Model>) async -> RefreshDisposition<Model>
    
    associatedtype Model
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

public enum LoadableError: Error, LocalizedError {
    case notSupported(String)
    case serviceNotSet
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



