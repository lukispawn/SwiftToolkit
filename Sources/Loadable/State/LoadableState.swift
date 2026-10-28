/// A common, immutable readiness projection for a value, a collection or a group.
/// Detailed data, query and cursor state remain on the original snapshots.
public struct LoadableState: Sendable {
    public enum Phase: Sendable, Equatable, CaseIterable {
        case idle, loading, loaded, failed
    }

    public enum Activity: Sendable, Equatable {
        case idle, loading, refreshing
        case loadingPage(LoadableCollection.Direction)
    }

    public enum Operation: Sendable, Equatable {
        case load
        case page(LoadableCollection.Direction)
    }

    public struct Failure: Sendable {
        public let error: any Error
        public let operation: Operation
        /// True only when the originating leaf has no successfully loaded result.
        public let isBlocking: Bool
    }

    public let storeCount: Int
    public let loadedStoreCount: Int
    /// Any active work, including refreshes and pagination after data is ready.
    public let isLoading: Bool
    public let isRefreshing: Bool
    public let isLoadingPage: Bool
    /// Input order is preserved, including failures from nested groups.
    public let failures: [Failure]

    /// All leaves have a successful result. An empty group is deliberately not ready.
    public var hasLoaded: Bool { storeCount > 0 && loadedStoreCount == storeCount }
    public var errors: [any Error] { failures.map(\.error) }
    public var blockingFailures: [Failure] { failures.filter(\.isBlocking) }

    public var phase: Phase {
        if hasLoaded { return .loaded }
        if failures.contains(where: \.isBlocking) { return .failed }
        return isLoading ? .loading : .idle
    }

    /// Constructs a single leaf, also usable by custom loading providers.
    /// Readiness and background activity are independent; failure severity is derived.
    public init(hasLoaded: Bool, activity: Activity = .idle,
                error: (any Error)? = nil, operation: Operation = .load) {
        storeCount = 1
        loadedStoreCount = hasLoaded ? 1 : 0
        isLoading = activity != .idle
        isRefreshing = activity == .refreshing
        if case .loadingPage = activity { isLoadingPage = true }
        else { isLoadingPage = false }
        failures = error.map { [Failure(error: $0, operation: operation, isBlocking: !hasLoaded)] } ?? []
    }

    public static var idle: Self { .init(hasLoaded: false) }
    public static var loading: Self { .init(hasLoaded: false, activity: .loading) }
    public static var loaded: Self { .init(hasLoaded: true) }

    /// Pure aggregation of current states. Does not start, await, cancel or retry work.
    /// Counts are additive: nested groups behave like their flattened leaves.
    public static func merge(_ states: [Self]) -> Self {
        Self(
            storeCount: states.reduce(0) { $0 + $1.storeCount },
            loadedStoreCount: states.reduce(0) { $0 + $1.loadedStoreCount },
            isLoading: states.contains(where: \.isLoading),
            isRefreshing: states.contains(where: \.isRefreshing),
            isLoadingPage: states.contains(where: \.isLoadingPage),
            failures: states.flatMap(\.failures)
        )
    }

    private init(storeCount: Int, loadedStoreCount: Int, isLoading: Bool,
                 isRefreshing: Bool, isLoadingPage: Bool, failures: [Failure]) {
        self.storeCount = storeCount
        self.loadedStoreCount = loadedStoreCount
        self.isLoading = isLoading
        self.isRefreshing = isRefreshing
        self.isLoadingPage = isLoadingPage
        self.failures = failures
    }
}
