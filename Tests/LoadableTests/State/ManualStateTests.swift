import Observation
import Testing
@testable import Loadable

/// The documented recipe: a private `LoadableState` field driven by hand, exposed through
/// `LoadableStateProviding`, for work that has no `Source` behind it.
@MainActor @Observable
private final class ManualOperationModel: LoadableStateProviding {
    private var refreshState = LoadableState.idle
    var loadableState: LoadableState { refreshState }

    func begin() { refreshState = .loading }
    func finish() { refreshState = .loaded }
    func fail(_ error: any Error) { refreshState = .failed(error) }
}

@MainActor
@Suite("Manually driven state")
struct ManualStateTests {
    @Test func failedFactoryIsABlockingLoadFailure() {
        let state = LoadableState.failed(TestFailure.offline)
        #expect(state.phase == .failed)
        #expect(!state.hasLoaded)
        #expect(!state.isLoading)
        #expect(state.failures.count == 1)
        #expect(state.failures.first?.isBlocking == true)
        #expect(state.failures.first?.operation == .load)
        #expect(state.firstBlockingError as? TestFailure == .offline)
        #expect(state.errors.count == 1)
    }

    @Test func firstBlockingErrorIsNilWithoutBlockingFailures() {
        #expect(LoadableState.idle.firstBlockingError == nil)
        #expect(LoadableState.loading.firstBlockingError == nil)
        #expect(LoadableState.loaded.firstBlockingError == nil)
        let retained = LoadableState(hasLoaded: true, error: TestFailure.rejected)
        #expect(retained.firstBlockingError == nil)
        #expect(retained.errors.count == 1)
    }

    @Test func firstBlockingErrorFollowsInputOrderAndSkipsRetainedFailures() {
        let merged = LoadableState.merge([
            .init(hasLoaded: true, error: TestFailure.rejected),
            .failed(TestFailure.offline),
            .failed(TestFailure.rejected),
        ])
        #expect(merged.firstBlockingError as? TestFailure == .offline)
        #expect(merged.blockingFailures.count == 2)
    }

    @Test func manualTransitionsProjectToPhases() {
        let model = ManualOperationModel()
        #expect(model.loadableState.phase == .idle)
        #expect(!model.loadableState.isLoading)

        model.begin()
        #expect(model.loadableState.phase == .loading)
        #expect(model.loadableState.isLoading)

        model.finish()
        #expect(model.loadableState.phase == .loaded)
        #expect(model.loadableState.hasLoaded)

        model.begin()
        model.fail(TestFailure.offline)
        #expect(model.loadableState.phase == .failed)
        #expect(model.loadableState.firstBlockingError as? TestFailure == .offline)

        // A later success clears the error because the field is replaced, not accumulated.
        model.finish()
        #expect(model.loadableState.phase == .loaded)
        #expect(model.loadableState.errors.isEmpty)
    }

    @Test func manualStateMergesWithARealStore() async throws {
        let source = ControlledValueSource<Int, String>()
        let store = LoadableValueStore(source: source)
        let model = ManualOperationModel()
        func merged() -> LoadableState { .merge(stores: [store, model]) }

        #expect(merged().phase == .idle)
        #expect(merged().storeCount == 2)

        store.start()
        await source.waitForCalls(1)
        let request = try #require(store.requestTask)
        #expect(merged().phase == .loading)

        await source.complete(0, .success(1))
        _ = await request.result
        // The store is ready, the manual operation is not: the group is not ready.
        #expect(merged().phase == .idle)
        #expect(!merged().hasLoaded)

        model.begin()
        #expect(merged().phase == .loading)
        model.fail(TestFailure.rejected)
        #expect(merged().phase == .failed)
        #expect(merged().firstBlockingError as? TestFailure == .rejected)

        model.finish()
        #expect(merged().phase == .loaded)
        #expect(merged().hasLoaded)
        #expect(merged().loadedStoreCount == 2)
    }

    @Test func manualStateIsObservedThroughTheProvider() async {
        let model = ManualOperationModel()
        await confirmation("Manual transition invalidates the read") { changed in
            withObservationTracking { _ = model.loadableState } onChange: { changed() }
            model.begin()
        }
    }
}
