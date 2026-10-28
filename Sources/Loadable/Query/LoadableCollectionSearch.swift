import Foundation
import Observation

/// Optional search coordination shared by lists and custom layouts.
/// The owner supplies query mapping and decides when to start/stop this controller.
@MainActor @Observable
public final class LoadableCollectionSearch<Source: LoadableCollectionSource> {
    public enum Requirement: Equatable {
        case satisfied(query: Source.Query)
        case tooShort(minimumLength: Int)
    }

    public var text: String {
        didSet { if text != oldValue { handleTextChange() } }
    }
    public private(set) var requirement: Requirement
    public let store: LoadableCollectionStore<Source>
    public let debouncer: LoadableQueryDebouncer<Source.Query>
    public let minimumLength: Int
    public let showsAllWhenEmpty: Bool
    @ObservationIgnored private let makeQuery: @Sendable (String) -> Source.Query

    public convenience init(
        store: LoadableCollectionStore<Source>, minimumLength: Int = 2,
        debounce: Duration = .milliseconds(400), showsAllWhenEmpty: Bool = true,
        initialText: String = "", makeQuery: @escaping @Sendable (String) -> Source.Query
    ) {
        self.init(store: store, minimumLength: minimumLength, debounce: debounce,
                  clock: ContinuousClock(), showsAllWhenEmpty: showsAllWhenEmpty,
                  initialText: initialText, makeQuery: makeQuery)
    }

    public init<C: Clock>(
        store: LoadableCollectionStore<Source>, minimumLength: Int = 2,
        debounce: C.Duration, clock: C, showsAllWhenEmpty: Bool = true,
        initialText: String = "", makeQuery: @escaping @Sendable (String) -> Source.Query
    ) {
        self.store = store
        self.minimumLength = max(1, minimumLength)
        self.showsAllWhenEmpty = showsAllWhenEmpty
        self.makeQuery = makeQuery
        text = initialText
        let normalized = initialText.trimmingCharacters(in: .whitespacesAndNewlines)
        requirement = (normalized.isEmpty ? showsAllWhenEmpty : normalized.count >= self.minimumLength)
            ? .satisfied(query: makeQuery(normalized)) : .tooShort(minimumLength: self.minimumLength)
        debouncer = LoadableQueryDebouncer(delay: debounce, clock: clock) { [weak store] query, submission in
            guard let store else { return }
            store.start(query: query, force: submission == .immediate || !store.snapshot.hasLoaded)
        }
    }

    public func startIfNeeded() {
        guard case .satisfied(let query) = requirement else { return }
        guard !debouncer.isWaiting else { return }
        store.start(query: query)
    }

    public func submitNow() {
        guard case .satisfied(let query) = requirement else { return }
        debouncer.submitNow(query)
    }

    /// Explicitly ends this search session. Views never call this implicitly on shared stores.
    public func stop() {
        debouncer.cancelPending()
        store.cancel()
    }

    private func handleTextChange() {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        debouncer.cancelPending()
        store.cancelRequest()
        guard normalized.isEmpty ? showsAllWhenEmpty : normalized.count >= minimumLength else {
            requirement = .tooShort(minimumLength: minimumLength)
            store.cancel()
            return
        }
        let query = makeQuery(normalized)
        requirement = .satisfied(query: query)
        debouncer.submit(query)
    }
}

public extension LoadableCollectionSearch where Source.Query == String {
    convenience init(
        store: LoadableCollectionStore<Source>, minimumLength: Int = 2,
        debounce: Duration = .milliseconds(400), showsAllWhenEmpty: Bool = true,
        initialText: String = ""
    ) {
        self.init(store: store, minimumLength: minimumLength, debounce: debounce,
                  showsAllWhenEmpty: showsAllWhenEmpty, initialText: initialText, makeQuery: { $0 })
    }
}
