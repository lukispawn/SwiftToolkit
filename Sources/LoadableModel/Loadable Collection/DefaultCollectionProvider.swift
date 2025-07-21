//
//  DefaultLoadableCollectionProvider.swift
//  LoadableModel
//
//  Created by Lukasz Zajdel on 31/05/2025.
//

public struct DefaultCollectionProvider<T:Identifiable & Sendable, C:Equatable & Sendable, Q: Equatable & Sendable>: LoadableCollectionProvider{
    
    public struct Configuration: Sendable {
        let inMemory: Bool
        public init(
            inMemory: Bool = false
        ) {
            self.inMemory = inMemory
        }
    }
    
    public typealias Model = T
    public typealias Cursor = C
    public typealias Query = Q
    
    enum Source: @unchecked Sendable {
        case constant(Result<[T], Error>)
        case provider(() async throws -> [T])
    }
    
    let source: Source
    let configuration: Configuration
    
    init(source: Source, configuration: Configuration = .init()) {
        self.source = source
        self.configuration = configuration
    }
    
    init(constant: Result<[T], Error>, configuration: Configuration = .init()) {
        self.source = .constant(constant)
        self.configuration = configuration
    }
    
    init(value: [T], configuration: Configuration = .init()) {
        self.source = .constant(.success(value))
        self.configuration = configuration
    }
    
    init(error: Error, configuration: Configuration = .init()) {
        self.source = .constant(.failure(error))
        self.configuration = configuration
    }
    
    init(operation provider: @escaping () async throws -> [T], configuration: Configuration = .init()) {
        self.source = .provider(provider)
        self.configuration = configuration
    }
    
    public func willLoad(previous: LoadedCollectionStatus<[T], C, Q>, query: Q?) async -> RefreshDisposition<LoadableCollectionResult<T, C>> {
        if let previous = previous.loadedData, configuration.inMemory {
            return .provide(.success(.init(data: previous.value, nextCursor: previous.nextCursor, previousCursor: previous.previousCursor, allCount: previous.allCount)))
        }else{
            return .proceed
        }
    }
    
    public func load(query: Q?) async throws -> LoadableCollectionResult<T, C> {
        switch source {
        case .constant(let result):
            switch result{
            case .success(let value):
                return .init(data: value, nextCursor: nil, previousCursor: nil, allCount: nil)
            case .failure(let error):
                throw error
            }
        case .provider(let operation):
            let value = try await operation()
            return .init(data: value, nextCursor: nil, previousCursor: nil, allCount: nil)
        }
    }
    
}



