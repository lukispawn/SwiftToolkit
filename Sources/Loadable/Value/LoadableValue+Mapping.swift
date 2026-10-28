public extension LoadableValueSource {
    /// Transforms a fetched value before publication. Mapping can introduce a new
    /// error type, so this adapter exposes `any Error` as its Failure.
    func mapValue<Output: Sendable>(
        _ transform: @escaping @Sendable (Value) async throws -> Output
    ) -> LoadableValue.MappedSource<Self, Output> {
        .init(base: self, transform: transform)
    }
}

extension LoadableValue {
    public struct MappedSource<Base: LoadableValueSource, Value: Sendable>: LoadableValueSource {
        public typealias Query = Base.Query
        public typealias Failure = any Error
        private let base: Base
        private let transform: @Sendable (Base.Value) async throws -> Value

        init(base: Base, transform: @escaping @Sendable (Base.Value) async throws -> Value) {
            self.base = base
            self.transform = transform
        }

        public func fetch(query: Query?) async throws -> Value {
            try Task.checkCancellation()
            let value = try await base.fetch(query: query)
            try Task.checkCancellation()
            let transformed = try await transform(value)
            try Task.checkCancellation()
            return transformed
        }
    }
}
