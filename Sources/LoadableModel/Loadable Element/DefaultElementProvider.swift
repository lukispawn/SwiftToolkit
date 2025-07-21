//
//  Untitled.swift
//  LoadableModel
//
//  Created by Lukasz Zajdel on 31/05/2025.
//

import Foundation

public struct DefaultElementProvider<T: Sendable>: LoadableElementProvider{
    
    public struct Configuration: Sendable {
        let inMemory: Bool
        public init(
            inMemory: Bool = false
        ) {
            self.inMemory = inMemory
        }
    }
    
    public typealias Model = T
    enum Source: @unchecked Sendable {
        case constant(Result<T, Error>)
        case provider(() async throws -> T)
    }
    
    let source: Source
    let configuration: Configuration
    
    init(source: Source, configuration: Configuration = .init()) {
        self.source = source
        self.configuration = configuration
    }
    
    init(constant: Result<T, Error>, configuration: Configuration = .init()) {
        self.source = .constant(constant)
        self.configuration = configuration
    }
    init(value: T, configuration: Configuration = .init()) {
        self.source = .constant(.success(value))
        self.configuration = configuration
    }
    init(error: Error, configuration: Configuration = .init()) {
        self.source = .constant(.failure(error))
        self.configuration = configuration
    }
    
    init(operation provider: @escaping () async throws -> T, configuration: Configuration = .init()) {
        self.source = .provider(provider)
        self.configuration = configuration
    }
    
    public func load() async throws -> T {
        switch source {
        case .constant(let result):
            switch result{
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        case .provider(let operation):
            return try await operation()
        }
    }
    
    public func willLoad(previous: LoadedElementStatus<T>) async -> RefreshDisposition<T> {
        if let previousValue = previous.value, configuration.inMemory {
            return .provide(.success(previousValue))
        }else{
            return .proceed
        }
        
    }
}

