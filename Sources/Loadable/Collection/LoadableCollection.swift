public enum LoadableCollection {
    public enum Direction: Sendable, Equatable, CaseIterable {
        case next
        case previous
    }

    public enum Operation: Sendable, Equatable {
        case reload
        case page(Direction)
    }

    public enum Phase<Failure: Error>: Sendable {
        case idle
        case loading
        case refreshing
        case loadingPage(Direction)
        case failed(Failure, operation: Operation)

        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing, .loadingPage: true
            default: false
            }
        }

        public var error: Failure? {
            if case .failed(let error, _) = self { error } else { nil }
        }
    }

    public struct Page<Item: Sendable, Cursor: Sendable>: Sendable {
        public let items: [Item]
        public let nextCursor: Cursor?
        public let previousCursor: Cursor?
        public let totalCount: Int?

        public init(items: [Item], nextCursor: Cursor? = nil, previousCursor: Cursor? = nil, totalCount: Int? = nil) {
            self.items = items
            self.nextCursor = nextCursor
            self.previousCursor = previousCursor
            self.totalCount = totalCount
        }
    }

    public struct Configuration: Sendable {
        public let prefetchThreshold: Int
        public let emptyPageFetchLimit: Int

        public init(prefetchThreshold: Int = 3, emptyPageFetchLimit: Int = 3) {
            self.prefetchThreshold = max(0, prefetchThreshold)
            self.emptyPageFetchLimit = max(0, emptyPageFetchLimit)
        }
    }

    public struct Snapshot<
        Item: Identifiable & Sendable,
        Cursor: Sendable & Equatable,
        Failure: Error,
        Query: Sendable & Equatable
    >: Sendable {
        public internal(set) var items: [Item]
        public internal(set) var phase: Phase<Failure>
        public internal(set) var nextCursor: Cursor?
        public internal(set) var previousCursor: Cursor?
        public internal(set) var totalCount: Int?
        public internal(set) var query: Query?
        public internal(set) var hasLoaded: Bool

        public init(
            items: [Item] = [], phase: Phase<Failure> = .idle,
            nextCursor: Cursor? = nil, previousCursor: Cursor? = nil,
            totalCount: Int? = nil, query: Query? = nil, hasLoaded: Bool = false
        ) {
            self.items = items
            self.phase = phase
            self.nextCursor = nextCursor
            self.previousCursor = previousCursor
            self.totalCount = totalCount
            self.query = query
            self.hasLoaded = hasLoaded
        }

        /// Terminal empty result; empty intermediate pages still allow pagination.
        public var isEmpty: Bool {
            hasLoaded && items.isEmpty && nextCursor == nil && previousCursor == nil
        }

        public func canLoad(_ direction: Direction) -> Bool {
            !phase.isLoading && phase.error == nil && cursor(for: direction) != nil
        }

        public func cursor(for direction: Direction) -> Cursor? {
            direction == .next ? nextCursor : previousCursor
        }

        public static var idle: Self { .init() }
        public static var loading: Self { .init(phase: .loading) }

        public static func loaded(
            _ items: [Item], nextCursor: Cursor? = nil, previousCursor: Cursor? = nil,
            totalCount: Int? = nil, query: Query? = nil
        ) -> Self {
            .init(items: items, nextCursor: nextCursor, previousCursor: previousCursor,
                  totalCount: totalCount, query: query, hasLoaded: true)
        }
    }
}

extension LoadableCollection.Phase: Equatable where Failure: Equatable {}
extension LoadableCollection.Page: Equatable where Item: Equatable, Cursor: Equatable {}
extension LoadableCollection.Snapshot: Equatable where Item: Equatable, Failure: Equatable {}

public extension LoadableCollection.Page where Cursor == Int {
    init(items: [Item], page: Int, pageSize: Int) {
        self.init(items: items, nextCursor: pageSize > 0 && items.count >= pageSize ? page + 1 : nil)
    }

    init(items: [Item], page: Int, firstPage: Int = 0, pageSize: Int, totalCount: Int) {
        let next: Int?
        if pageSize > 0, totalCount > 0 {
            let lastPage = firstPage + (totalCount - 1) / pageSize
            next = page < lastPage ? page + 1 : nil
        } else {
            next = nil
        }
        self.init(items: items, nextCursor: next, totalCount: totalCount)
    }
}
