public protocol LoadableCollectionSource: Sendable {
    associatedtype Item: Identifiable & Sendable
    associatedtype Cursor: Sendable & Equatable = Never
    associatedtype Query: Sendable & Equatable = Never
    associatedtype Failure: Error = any Error

    typealias Page = LoadableCollection.Page<Item, Cursor>

    /// A nil cursor requests the first page. Its direction is always .next.
    /// Query is supplied explicitly on every page, including retries.
    func fetchPage(query: Query?, cursor: Cursor?, direction: LoadableCollection.Direction) async throws(Failure) -> Page
}

extension LoadableCollection {
    public struct ConstantSource<Item: Identifiable & Sendable>: LoadableCollectionSource {
        public typealias Cursor = Never
        public typealias Query = Never
        public typealias Failure = Never
        private let items: [Item]

        public init(_ items: [Item]) { self.items = items }
        public func fetchPage(query: Never?, cursor: Never?, direction: Direction) async -> Page<Item, Never> {
            .init(items: items)
        }
    }

    public struct OperationSource<
        Item: Identifiable & Sendable, Cursor: Sendable & Equatable,
        Query: Sendable & Equatable, Failure: Error
    >: LoadableCollectionSource {
        private let operation: @Sendable (Query?, Cursor?, Direction) async throws(Failure) -> Page<Item, Cursor>

        public init(_ operation: @escaping @Sendable (Query?, Cursor?, Direction) async throws(Failure) -> Page<Item, Cursor>) {
            self.operation = operation
        }

        public func fetchPage(query: Query?, cursor: Cursor?, direction: Direction) async throws(Failure) -> Page<Item, Cursor> {
            try await operation(query, cursor, direction)
        }
    }
}
