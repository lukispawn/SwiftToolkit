public extension LoadableCollectionStore {
    /// A frozen presentation without a custom source. For a loaded result use init(items:).
    /// The Item type must be supplied by items or the surrounding store/row type.
    convenience init<Item>(
        items: [Item] = [], phase: LoadableCollection.Phase<any Error>, hasLoaded: Bool? = nil
    ) where Source == LoadableCollection.OperationSource<Item, Never, Never, any Error> {
        let snapshot = Snapshot(items: items, phase: phase,
                                hasLoaded: hasLoaded ?? phase.inferredHasLoaded(hasItems: !items.isEmpty))
        self.init(source: .init { _, _, _ in .init(items: items) }, constantSnapshot: snapshot)
    }
}

private extension LoadableCollection.Phase {
    func inferredHasLoaded(hasItems: Bool) -> Bool {
        switch self {
        case .refreshing, .loadingPage, .failed(_, .page): true
        case .idle, .loading, .failed(_, .reload): hasItems
        }
    }
}

public extension LoadableCollection.Phase {
    /// Failure of the initial fetch or refresh. Use operation: .page(...) for page failures.
    static func failed(_ error: Failure) -> Self { .failed(error, operation: .reload) }
}
