extension LoadableUI {
    /// A rendering decision derived from a snapshot, without owning requests or UI state.
    public struct Presentation: Sendable, Equatable {
        public enum State: Sendable, Equatable {
            case idle, loading, empty, failed, content
        }

        public let state: State
        public let isRefreshing: Bool

        public init<Item, Cursor, Failure, Query>(
            snapshot: LoadableCollection.Snapshot<Item, Cursor, Failure, Query>
        ) {
            isRefreshing = snapshot.phase.isRefreshing
            if !snapshot.items.isEmpty {
                state = .content
            } else if snapshot.phase.error != nil {
                state = .failed
            } else if snapshot.phase.isLoading {
                state = .loading
            } else if !snapshot.hasLoaded {
                state = .idle
            } else {
                // An empty intermediate page is actionable, not a terminal empty result.
                state = snapshot.isEmpty ? .empty : .content
            }
        }
    }
}

private extension LoadableCollection.Phase {
    var isRefreshing: Bool { if case .refreshing = self { true } else { false } }
}

