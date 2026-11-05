import Observation

/// State behind `LoadableImage`. Isolation: everything is `@MainActor`; the source runs elsewhere.
///
/// Rules: a key with the same `contentID` as the visible image waits `debounce` and keeps the old
/// image while loading; a different `contentID` clears the image at once and loads without waiting;
/// the first load never waits; cancellation never produces a failure.
@MainActor @Observable
final class LoadableImageModel<Source: LoadableImageSource> {
    enum Phase {
        case none
        case loading(previous: LoadableImageValue?)
        case loaded(LoadableImageValue)
        case failed(any Error)
    }

    private(set) var phase: Phase = .none

    @ObservationIgnored private let store: LoadableValueStore<Source>
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var requestedKey: Source.Query?
    @ObservationIgnored private var loadedKey: Source.Query?
    @ObservationIgnored private var loadedValue: LoadableImageValue?
    @ObservationIgnored private var contentID: Source.Query.ContentID?

    init(source: Source, debounce: Duration = .milliseconds(150)) {
        store = LoadableValueStore(source: source)
        self.debounce = debounce
    }

    var image: LoadableImageValue? {
        switch phase {
        case .loaded(let value): value
        case .loading(let previous): previous
        case .none, .failed: nil
        }
    }

    var isLoading: Bool {
        if case .loading = phase { true } else { false }
    }

    var isNone: Bool {
        if case .none = phase { true } else { false }
    }

    var error: (any Error)? {
        if case .failed(let error) = phase { error } else { nil }
    }

    /// Call from `.task(id: key)`. Returns early (without changing state) when cancelled.
    func update(key: Source.Query?) async {
        guard let key else {
            reset()
            return
        }
        requestedKey = key
        if key == loadedKey, let loadedValue {
            phase = .loaded(loadedValue)
            return
        }
        if contentID == key.contentID, let visible = loadedValue {
            do { try await Task.sleep(for: debounce) } catch { return }
            phase = .loading(previous: visible)
        } else {
            contentID = key.contentID
            loadedKey = nil
            loadedValue = nil
            phase = .loading(previous: nil)
        }
        await load(key)
    }

    func retry() async {
        guard case .failed = phase, let key = requestedKey else { return }
        phase = .loading(previous: nil)
        await load(key)
    }

    private func reset() {
        store.cancelRequest()
        requestedKey = nil
        loadedKey = nil
        loadedValue = nil
        contentID = nil
        phase = .none
    }

    private func load(_ key: Source.Query) async {
        do {
            let value = try await store.load(query: key)
            guard !Task.isCancelled else { return }
            loadedKey = key
            loadedValue = value
            phase = .loaded(value)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error)
        }
    }
}
