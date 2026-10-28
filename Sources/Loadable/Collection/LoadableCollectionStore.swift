import Foundation
import Observation

@MainActor @Observable
public final class LoadableCollectionStore<Source: LoadableCollectionSource> {
    public typealias Item = Source.Item
    public typealias Query = Source.Query
    public typealias Cursor = Source.Cursor
    public typealias Failure = Source.Failure
    public typealias Page = LoadableCollection.Page<Item, Cursor>
    public typealias Snapshot = LoadableCollection.Snapshot<Item, Cursor, Failure, Query>
    public typealias Direction = LoadableCollection.Direction
    public typealias Merge = @Sendable (_ existing: [Item], _ incoming: [Item], _ direction: Direction) -> [Item]

    public private(set) var snapshot: Snapshot {
        didSet { snapshotChannel.yield(snapshot) }
    }
    public var items: [Item] { snapshot.items }
    public var lastError: Failure? { snapshot.phase.error }
    public var canLoadMore: Bool { canLoad(.next) }
    public var canReload: Bool { !isConstant }
    public var canRetry: Bool {
        !isConstant && hasSession && snapshot.phase.error != nil && inFlight == nil && failedFetch != nil
    }

    // These observable flags affect command availability, unlike internal task handles.
    private var hasSession = false
    private var isConstant = false
    @ObservationIgnored let source: Source
    @ObservationIgnored let configuration: LoadableCollection.Configuration
    @ObservationIgnored let merge: Merge
    @ObservationIgnored var inFlight: RequestHandle<[Item]>?
    @ObservationIgnored var failedFetch: Fetch?
    @ObservationIgnored private let snapshotChannel = SnapshotChannel<Snapshot>()
    // A new reload/refresh resets UI edge-trigger history, even for a reused query.
    private(set) var paginationSessionID = UUID()

    struct Fetch: Sendable {
        let query: Query?
        let cursor: Cursor?
        let direction: Direction
        let replacesItems: Bool
        let retainingItems: Bool

        var operation: LoadableCollection.Operation {
            replacesItems ? .reload : .page(direction)
        }
    }

    public init(
        source: Source,
        configuration: LoadableCollection.Configuration = .init(),
        merge: Merge? = nil
    ) {
        self.source = source
        self.configuration = configuration
        self.merge = merge ?? { existing, incoming, direction in
            LoadableCollection.mergeByID(existing: existing, incoming: incoming, direction: direction)
        }
        snapshot = .idle
    }

    public convenience init(source: Source, constantSnapshot: Snapshot) {
        self.init(source: source)
        setConstantState(constantSnapshot)
    }

    deinit { inFlight?.task.cancel() }

    public func start(query: Query? = nil, force: Bool = false) {
        guard !isConstant, force || !hasSession || snapshot.query != query else { return }
        beginReload(query: query, retainingItems: false)
    }

    public func startIfNeeded() {
        guard !isConstant, !snapshot.hasLoaded, inFlight == nil, lastError == nil else { return }
        beginReload(query: snapshot.query, retainingItems: false)
    }

    public func reload() {
        guard !isConstant else { return }
        beginReload(query: snapshot.query, retainingItems: false)
    }

    /// Store-owned; cancellation of the awaiting caller does not cancel the fetch.
    public func refresh() async {
        guard !isConstant else { return }
        let request = beginReload(query: snapshot.query, retainingItems: true)
        _ = await request.task.result
    }

    /// Retained, store-owned refresh for persistence events or synchronous triggers.
    public func refreshInBackground() {
        guard !isConstant else { return }
        beginReload(query: snapshot.query, retainingItems: true)
    }

    /// Each subscription has its own buffer and receives the current snapshot immediately.
    public func snapshots(
        bufferingPolicy: AsyncStream<Snapshot>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Snapshot> {
        snapshotChannel.stream(initial: snapshot, bufferingPolicy: bufferingPolicy)
    }

    /// Replacing membership invalidates server cursors, whose offsets may now be stale.
    /// Refresh or start a session before requesting further pages.
    public func setItems(_ items: [Item], totalCount: Int? = nil) {
        guard !isConstant else { return }
        cancelRequest()
        failedFetch = nil
        hasSession = false
        snapshot = .loaded(
            LoadableCollection.mergeByID(existing: [], incoming: items, direction: .next),
            totalCount: totalCount, query: snapshot.query
        )
    }

    /// Replaces an existing row without changing membership or server cursors.
    @discardableResult
    public func updateItem(_ item: Item) -> Bool {
        guard !isConstant, snapshot.hasLoaded,
              let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        cancelRequest()
        failedFetch = nil
        var updated = snapshot
        updated.items[index] = item
        updated.phase = .idle
        snapshot = updated
        return true
    }

    @discardableResult
    public func removeItem(withID id: Item.ID) -> Item? {
        guard !isConstant, snapshot.hasLoaded,
              let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        var remaining = items
        let removed = remaining.remove(at: index)
        setItems(remaining)
        return removed
    }

    public func appendItems(_ incoming: [Item]) {
        guard !isConstant, !incoming.isEmpty else { return }
        setItems(LoadableCollection.mergeByID(existing: items, incoming: incoming, direction: .next))
    }

    /// Caller-owned first-page load. Previous callers cannot cancel newer requests.
    @discardableResult
    public func load(query: Query? = nil, retainingItems: Bool = false) async throws -> [Item] {
        try Task.checkCancellation()
        if isConstant {
            guard snapshot.hasLoaded else { throw LoadableUsageError.constantHasNoValue }
            return items
        }
        let request = beginReload(query: query, retainingItems: retainingItems && snapshot.query == query)
        return try await awaitRequest(request) { [weak self] id in self?.cancelRequest(id: id) }
    }

    /// Command availability also includes session lifetime and frozen-preview state.
    public func canLoad(_ direction: Direction) -> Bool {
        hasSession && !isConstant && snapshot.canLoad(direction)
    }

    public func loadMore() { loadPage(.next) }

    public func loadPage(_ direction: Direction) {
        guard canLoad(direction), inFlight == nil, let cursor = snapshot.cursor(for: direction) else { return }
        begin(fetch: Fetch(query: snapshot.query, cursor: cursor, direction: direction,
                           replacesItems: false, retainingItems: true))
    }

    public func loadMoreIfNeeded(for item: Item) {
        guard canLoadMore, let index = items.firstIndex(where: { $0.id == item.id }),
              index >= max(0, items.count - configuration.prefetchThreshold - 1) else { return }
        loadMore()
    }

    public func retry() {
        guard !isConstant, hasSession, inFlight == nil, let failedFetch else { return }
        begin(fetch: failedFetch)
    }

    public func cancelRequest() {
        guard let id = inFlight?.id else { return }
        cancelRequest(id: id)
    }

    public func cancel() {
        cancelRequest()
        hasSession = false
        failedFetch = nil
    }

    public func setConstantState(_ snapshot: Snapshot) {
        cancel()
        isConstant = true
        self.snapshot = snapshot
    }

    var requestTask: Task<[Item], any Error>? { inFlight?.task }

    @discardableResult
    private func beginReload(query: Query?, retainingItems: Bool) -> RequestHandle<[Item]> {
        paginationSessionID = UUID()
        hasSession = true
        return begin(fetch: Fetch(query: query, cursor: nil, direction: .next,
                                  replacesItems: true, retainingItems: retainingItems))
    }

    func cancelRequest(id: UUID) {
        guard inFlight?.id == id else { return }
        inFlight?.task.cancel()
        finish(id: id)
    }

    func finish(id: UUID) {
        guard inFlight?.id == id else { return }
        inFlight = nil
        if snapshot.phase.isLoading { snapshot.phase = .idle }
    }
}

public extension LoadableCollectionStore {
    convenience init<Item>(items: [Item]) where Source == LoadableCollection.ConstantSource<Item> {
        self.init(source: .init(items), constantSnapshot: .loaded(items))
    }

    convenience init<Item, Failure>(operation: @escaping @Sendable () async throws(Failure) -> [Item])
    where Source == LoadableCollection.OperationSource<Item, Never, Never, Failure> {
        self.init(source: .init { _, _, _ throws(Failure) in .init(items: try await operation()) })
    }
}

extension LoadableCollectionStore {
    @discardableResult
    func begin(fetch: Fetch) -> RequestHandle<[Item]> {
        cancelRequest()
        failedFetch = nil
        var updated = snapshot
        if fetch.replacesItems {
            if !fetch.retainingItems {
                updated = .init(query: fetch.query)
            }
            updated.phase = updated.hasLoaded ? .refreshing : .loading
        } else {
            updated.phase = .loadingPage(fetch.direction)
        }
        snapshot = updated
        let id = UUID()
        let task = Task { [weak self, source, configuration] () throws -> [Item] in
            defer { self?.finish(id: id) }
            var currentFetch = fetch
            var visited = fetch.cursor.map { [$0] } ?? []
            var additionalPages = 0

            while true {
                try Task.checkCancellation()
                guard self?.inFlight?.id == id else { throw CancellationError() }
                let result: Result<Page, Failure>
                do throws(Failure) {
                    result = .success(try await source.fetchPage(
                        query: currentFetch.query, cursor: currentFetch.cursor, direction: currentFetch.direction
                    ))
                } catch { result = .failure(error) }

                try Task.checkCancellation()
                guard self?.inFlight?.id == id else { throw CancellationError() }
                switch result {
                case .failure(let error):
                    if error is CancellationError { throw CancellationError() }
                    self?.failedFetch = currentFetch
                    self?.snapshot.phase = .failed(error, operation: currentFetch.operation)
                    throw error
                case .success(let page):
                    self?.accept(page, for: currentFetch)
                    let continuation = currentFetch.direction == .next ? page.nextCursor : page.previousCursor
                    guard page.items.isEmpty, let cursor = continuation,
                          !visited.contains(cursor), additionalPages < configuration.emptyPageFetchLimit else {
                        return self?.items ?? []
                    }
                    visited.append(cursor)
                    additionalPages += 1
                    currentFetch = Fetch(query: fetch.query, cursor: cursor, direction: fetch.direction,
                                         replacesItems: false, retainingItems: true)
                    self?.snapshot.phase = .loadingPage(fetch.direction)
                }
            }
        }
        let request = RequestHandle(id: id, task: task)
        inFlight = request
        return request
    }

    private func accept(_ page: Page, for fetch: Fetch) {
        if fetch.replacesItems {
            snapshot = .loaded(
                LoadableCollection.mergeByID(existing: [], incoming: page.items, direction: .next),
                nextCursor: page.nextCursor, previousCursor: page.previousCursor,
                totalCount: page.totalCount, query: fetch.query
            )
        } else {
            var updated = snapshot
            updated.items = merge(items, page.items, fetch.direction)
            if fetch.direction == .next { updated.nextCursor = page.nextCursor }
            else { updated.previousCursor = page.previousCursor }
            if let totalCount = page.totalCount { updated.totalCount = totalCount }
            updated.phase = .idle
            updated.hasLoaded = true
            snapshot = updated
        }
    }
}
