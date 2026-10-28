import Testing
@testable import Loadable

typealias FrozenRows = LoadableCollectionStore<LoadableCollection.OperationSource<Row, Never, Never, any Error>>
typealias FrozenValue = LoadableValueStore<LoadableValue.OperationSource<String?, Never, any Error>>

@MainActor
@Suite("Convenient frozen store initialization")
struct ConstantStateInitializerTests {
    @Test func collectionLoadingNeedsOnlyAnItemTypeAndPhase() async {
        let store = FrozenRows(phase: .loading)
        store.start()
        store.reload()
        store.cancelRequest()
        store.setItems([Row(9)])
        await store.refresh()
        #expect(store.requestTask == nil)
        #expect(store.snapshot.phase.isLoading)
        #expect(store.items.isEmpty)
        #expect(store.loadableState.phase == .loading)
        #expect(!store.canReload)
    }

    @Test func initialCollectionFailureHasAnActualErrorAndNoRetryAction() {
        let store = FrozenRows(phase: .failed(TestFailure.offline))
        #expect(store.lastError as? TestFailure == .offline)
        #expect(store.snapshot.phase.error as? TestFailure == .offline)
        #expect(store.loadableState.phase == .failed)
        #expect(store.loadableState.failures.first?.operation == .load)
        #expect(!store.canRetry)
        store.retry()
        #expect(store.requestTask == nil)
    }

    @Test func collectionInitializerInfersItemFromRetainedItems() async throws {
        let store = LoadableCollectionStore(items: [Row(1)], phase: .failed(TestFailure.rejected, operation: .page(.next)))
        #expect(store.loadableState.phase == .loaded)
        #expect(store.loadableState.blockingFailures.isEmpty)
        #expect(store.loadableState.failures.first?.operation == .page(.next))
        #expect(try await store.load() == [Row(1)])
        store.updateItem(Row(1, version: 2))
        store.appendItems([Row(2)])
        #expect(store.items == [Row(1)])
    }

    @Test(arguments: [LoadableCollection.Phase<any Error>.refreshing, .loadingPage(.next),
                      .loadingPage(.previous), .failed(TestFailure.offline, operation: .page(.previous))])
    func emptyRetainedActivityHasAPriorSuccessfulResult(phase: LoadableCollection.Phase<any Error>) {
        let store = FrozenRows(phase: phase)
        #expect(store.snapshot.hasLoaded)
        #expect(store.loadableState.phase == .loaded)
    }

    @Test func explicitReadinessDisambiguatesFailedRefreshOfEmptyResult() {
        let ready = FrozenRows(phase: .failed(TestFailure.offline), hasLoaded: true)
        let missing = FrozenRows(phase: .failed(TestFailure.offline), hasLoaded: false)
        #expect(ready.loadableState.phase == .loaded)
        #expect(missing.loadableState.phase == .failed)
    }

    @Test func explicitReadinessCanRepresentAnUnloadedPageFailure() {
        let store = FrozenRows(phase: .failed(TestFailure.offline, operation: .page(.next)), hasLoaded: false)
        #expect(store.loadableState.phase == .failed)
        #expect(store.loadableState.failures.first?.isBlocking == true)
    }

    @Test func idleEmptyPhaseAndLoadedEmptyItemsHaveDifferentSemantics() {
        let idle = FrozenRows(phase: .idle)
        let loaded = LoadableCollectionStore(items: [Row]())
        #expect(idle.loadableState.phase == .idle)
        #expect(loaded.loadableState.phase == .loaded)
        #expect(FrozenRows(items: [Row(1)], phase: .idle).loadableState.phase == .loaded)
    }

    @Test func valueLoadingIsFrozenAndMissingValueLoadThrowsUsageError() async {
        let store = FrozenValue(phase: .loading)
        store.start()
        store.reload()
        store.retry()
        store.setValue("Updated")
        await store.refresh()
        #expect(store.requestTask == nil)
        #expect(store.snapshot.phase.isLoading)
        #expect(!store.loadableState.hasLoaded)
        await #expect(throws: LoadableUsageError.constantHasNoValue) { try await store.load() }
    }

    @Test func valueFailureIsFrozenWithoutACustomSource() {
        let store = FrozenValue(phase: .failed(TestFailure.offline))
        #expect(store.loadableState.phase == .failed)
        #expect(store.lastError as? TestFailure == .offline)
        store.retry()
        #expect(store.requestTask == nil)
    }

    @Test func valueInitializerInfersTypeFromRetainedOptionalNil() async throws {
        let store = LoadableValueStore(constant: String?.none, phase: .failed(TestFailure.offline))
        #expect(store.snapshot.hasValue)
        #expect(store.loadableState.phase == .loaded)
        #expect(store.loadableState.blockingFailures.isEmpty)
        #expect(try await store.load() == nil)
    }

    @Test func retainedValueRefreshRemainsFrozen() async throws {
        let store = LoadableValueStore(constant: "Profile", phase: .refreshing)
        store.refreshInBackground()
        store.setValue("Different")
        #expect(store.loadableState.isRefreshing)
        #expect(store.loadableState.phase == .loaded)
        #expect(store.value == "Profile")
        #expect(try await store.load() == "Profile")
        #expect(store.requestTask == nil)
    }
}
