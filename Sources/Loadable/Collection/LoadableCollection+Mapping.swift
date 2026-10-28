public extension LoadableCollectionSource {
    /// Transforms each page, preserving its server cursors and total count.
    /// This is page-level processing, not a transform of the accumulated list.
    func mapItems<Output: Identifiable & Sendable>(
        _ transform: @escaping @Sendable ([Item]) async throws -> [Output]
    ) -> LoadableCollection.MappedSource<Self, Output> {
        .init(base: self, transform: transform)
    }
}

extension LoadableCollection {
    public struct MappedSource<Base: LoadableCollectionSource, Item: Identifiable & Sendable>: LoadableCollectionSource {
        public typealias Query = Base.Query
        public typealias Cursor = Base.Cursor
        public typealias Failure = any Error
        private let base: Base
        private let transform: @Sendable ([Base.Item]) async throws -> [Item]

        init(base: Base, transform: @escaping @Sendable ([Base.Item]) async throws -> [Item]) {
            self.base = base
            self.transform = transform
        }

        public func fetchPage(query: Query?, cursor: Cursor?, direction: Direction) async throws -> LoadableCollection.Page<Item, Cursor> {
            try Task.checkCancellation()
            let page = try await base.fetchPage(query: query, cursor: cursor, direction: direction)
            try Task.checkCancellation()
            let transformed = try await transform(page.items)
            try Task.checkCancellation()
            return .init(items: transformed, nextCursor: page.nextCursor,
                        previousCursor: page.previousCursor, totalCount: page.totalCount)
        }
    }
}
