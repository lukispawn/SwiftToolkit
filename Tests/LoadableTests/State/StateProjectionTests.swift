import Testing
import Loadable

@Suite("Value and collection common state projections")
struct StateProjectionTests {
    typealias ValueSnapshot = LoadableValue.Snapshot<String?, TestFailure, String>
    typealias CollectionSnapshot = LoadableCollection.Snapshot<Row, Int, TestFailure, String>

    @Test func loadedOptionalNilIsReady() {
        let state = ValueSnapshot.loaded(nil).loadableState
        #expect(state.phase == .loaded)
        #expect(state.hasLoaded)
        #expect(state.loadedStoreCount == 1)
    }

    @Test(arguments: [false, true])
    func valueFailureSeverityDependsOnRetainedResult(retaining: Bool) {
        let snapshot = ValueSnapshot(content: retaining ? .value(nil) : .missing, phase: .failed(.offline))
        let state = snapshot.loadableState
        #expect(state.phase == (retaining ? .loaded : .failed))
        #expect(state.failures.first?.isBlocking == !retaining)
        #expect(state.failures.first?.operation == .load)
        #expect(state.errors.first as? TestFailure == .offline)
    }

    @Test(arguments: [LoadableValue.Phase<TestFailure>.idle, .loading, .refreshing])
    func valueActivityIsIndependentFromContent(phase: LoadableValue.Phase<TestFailure>) {
        for hasValue in [false, true] {
            let state = ValueSnapshot(content: hasValue ? .value("value") : .missing, phase: phase).loadableState
            #expect(state.hasLoaded == hasValue)
            #expect(state.isLoading == phase.isLoading)
            if case .refreshing = phase { #expect(state.isRefreshing) }
            else { #expect(!state.isRefreshing) }
            #expect(!state.isLoadingPage)
        }
    }

    @Test func emptyAndIntermediateCollectionsBothCountAsSuccessfullyLoaded() {
        for snapshot in [CollectionSnapshot.loaded([]), .loaded([], nextCursor: 1), .loaded([], previousCursor: -1)] {
            #expect(snapshot.loadableState.phase == .loaded)
            #expect(snapshot.loadableState.hasLoaded)
        }
    }

    @Test func collectionIdleAndInitialLoadingAreDistinct() {
        #expect(CollectionSnapshot.idle.loadableState.phase == .idle)
        #expect(CollectionSnapshot.loading.loadableState.phase == .loading)
        #expect(!CollectionSnapshot.loading.loadableState.hasLoaded)
    }

    @Test(arguments: [false, true], [LoadableCollection.Operation.reload, .page(.next), .page(.previous)])
    func collectionFailureRetainsDirectionAndReadiness(retaining: Bool, operation: LoadableCollection.Operation) {
        let state = CollectionSnapshot(phase: .failed(.rejected, operation: operation), hasLoaded: retaining).loadableState
        #expect(state.phase == (retaining ? .loaded : .failed))
        #expect(state.errors.first as? TestFailure == .rejected)
        #expect(state.failures.first?.isBlocking == !retaining)
        let expected: LoadableState.Operation
        switch operation {
        case .reload: expected = .load
        case .page(let direction): expected = .page(direction)
        }
        #expect(state.failures.first?.operation == expected)
    }

    @Test(arguments: [LoadableCollection.Phase<TestFailure>.idle, .loading, .refreshing,
                      .loadingPage(.next), .loadingPage(.previous)])
    func collectionActivityPreservesLoadedResult(phase: LoadableCollection.Phase<TestFailure>) {
        let state = CollectionSnapshot(items: [], phase: phase, hasLoaded: true).loadableState
        #expect(state.phase == .loaded)
        #expect(state.isLoading == phase.isLoading)
        if case .refreshing = phase { #expect(state.isRefreshing) }
        else { #expect(!state.isRefreshing) }
        if case .loadingPage = phase { #expect(state.isLoadingPage) }
        else { #expect(!state.isLoadingPage) }
    }

    @Test func collectionReadinessUsesSuccessMetadataRatherThanRowCount() {
        let snapshot = CollectionSnapshot(items: [Row(1)], hasLoaded: false)
        #expect(snapshot.loadableState.phase == .idle)
        #expect(!snapshot.loadableState.hasLoaded)
    }

    @Test func mixedTypedSourcesMergeWithoutErasingTheirData() {
        let value = ValueSnapshot.loaded(nil)
        let collection = CollectionSnapshot.loaded([])
        let state = LoadableState.merge([value.loadableState, collection.loadableState])
        #expect(state.phase == .loaded)
        #expect(state.loadedStoreCount == 2)
        #expect(value.hasValue)
        #expect(collection.items.isEmpty)
    }
}
