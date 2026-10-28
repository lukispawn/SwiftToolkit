extension LoadableUI {
    /// Failure information and an optional action. Frozen or ended sessions have no retry.
    @MainActor
    public struct FailureContext<Failure: Error> {
        public let error: Failure
        public let operation: LoadableCollection.Operation
        public let retry: (@MainActor () -> Void)?
    }

    /// A live, MainActor-isolated facade over the injected store. Does not own a task.
    @MainActor
    public struct CollectionContext<Source: LoadableCollectionSource> {
        let store: LoadableCollectionStore<Source>
        public let configuration: LoadableUI.Configuration

        public init(store: LoadableCollectionStore<Source>, configuration: LoadableUI.Configuration = .init()) {
            self.store = store
            self.configuration = configuration
        }

        public var items: [Source.Item] { store.items }
        public var query: Source.Query? { store.snapshot.query }
        public var totalCount: Int? { store.snapshot.totalCount }
        public var phase: LoadableCollection.Phase<Source.Failure> { store.snapshot.phase }
        public var presentation: LoadableUI.Presentation { .init(snapshot: store.snapshot) }
        public var canRefresh: Bool { configuration.isRefreshable && store.canReload }

        public var failure: LoadableUI.FailureContext<Source.Failure>? {
            guard case .failed(let error, let operation) = phase else { return nil }
            let retry: (@MainActor () -> Void)? = store.canRetry ? { @MainActor [store] in store.retry() } : nil
            return .init(error: error, operation: operation, retry: retry)
        }

        public var refreshFailure: LoadableUI.FailureContext<Source.Failure>? {
            guard !items.isEmpty, let failure, failure.operation == .reload else { return nil }
            return failure
        }

        public var pagination: LoadableUI.PaginationContext<Source> { pagination(.next) }

        public func pagination(_ direction: LoadableCollection.Direction) -> LoadableUI.PaginationContext<Source> {
            .init(collection: self, direction: direction)
        }

        public func startIfNeeded() {
            guard configuration.startsAutomatically else { return }
            store.startIfNeeded()
        }

        public func refresh() async {
            guard canRefresh else { return }
            await store.refresh()
        }

        public func reload() { store.reload() }
        public func retry() { failure?.retry?() }

        public func itemAppeared(_ item: Source.Item) {
            guard configuration.pagination == .automatic else { return }
            store.loadMoreIfNeeded(for: item)
        }
    }

    @MainActor
    public struct PaginationContext<Source: LoadableCollectionSource> {
        public enum State: Sendable, Equatable {
            case hidden, available, loading, failed
        }

        let collection: LoadableUI.CollectionContext<Source>
        public let direction: LoadableCollection.Direction

        public var state: State {
            guard collection.configuration.pagination != .disabled else { return .hidden }
            if case .loadingPage(let direction) = collection.phase, direction == self.direction { return .loading }
            if failure != nil { return .failed }
            return collection.store.canLoad(direction) ? .available : .hidden
        }

        public var failure: LoadableUI.FailureContext<Source.Failure>? {
            guard collection.configuration.pagination != .disabled,
                  let failure = collection.failure, failure.operation == .page(direction) else { return nil }
            return failure
        }

        /// Explicit loading is also available after bounded empty-page continuation stops.
        public func load() {
            guard state == .available else { return }
            collection.store.loadPage(direction)
        }

        public func retry() { failure?.retry?() }
    }
}
