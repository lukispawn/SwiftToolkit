/// A read-only facade for heterogeneous stores and computed ViewModel groups.
/// Reading through the protocol preserves the underlying Observation tracking.
@MainActor
public protocol LoadableStateProviding {
    var loadableState: LoadableState { get }
}

extension LoadableValueStore: LoadableStateProviding {
    public var loadableState: LoadableState { snapshot.loadableState }
}

extension LoadableCollectionStore: LoadableStateProviding {
    public var loadableState: LoadableState { snapshot.loadableState }
}

public extension LoadableState {
    /// Eagerly reads every provider on MainActor before performing the pure merge.
    /// The returned value is a snapshot; compute it again to observe later changes.
    @MainActor
    static func merge(stores: [any LoadableStateProviding]) -> Self {
        merge(stores.map(\.loadableState))
    }
}
