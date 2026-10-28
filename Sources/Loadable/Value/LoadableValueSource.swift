public protocol LoadableValueSource: Sendable {
    associatedtype Value: Sendable
    associatedtype Query: Sendable & Equatable = Never
    associatedtype Failure: Error = any Error

    func fetch(query: Query?) async throws(Failure) -> Value
}

extension LoadableValue {
    public struct ConstantSource<Value: Sendable>: LoadableValueSource {
        public typealias Query = Never
        public typealias Failure = Never
        private let value: Value

        public init(_ value: Value) { self.value = value }
        public func fetch(query: Never?) async -> Value { value }
    }

    public struct OperationSource<Value: Sendable, Query: Sendable & Equatable, Failure: Error>: LoadableValueSource {
        private let operation: @Sendable (Query?) async throws(Failure) -> Value

        public init(_ operation: @escaping @Sendable (Query?) async throws(Failure) -> Value) {
            self.operation = operation
        }

        public func fetch(query: Query?) async throws(Failure) -> Value {
            try await operation(query)
        }
    }
}
