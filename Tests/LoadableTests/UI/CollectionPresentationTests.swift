import Testing
@testable import Loadable

@Suite("Collection presentation decisions")
struct CollectionPresentationTests {
    typealias Snapshot = CollectionStore.Snapshot

    @Test func idleIsDistinctFromLoadingAndTerminalEmpty() {
        #expect(LoadableUI.Presentation(snapshot: Snapshot.idle).state == .idle)
        #expect(LoadableUI.Presentation(snapshot: Snapshot.loading).state == .loading)
        #expect(LoadableUI.Presentation(snapshot: Snapshot.loaded([])).state == .empty)
    }

    @Test(arguments: [LoadableCollection.Phase<TestFailure>.idle, .loading, .refreshing,
                      .loadingPage(.next), .loadingPage(.previous),
                      .failed(.offline, operation: .reload), .failed(.offline, operation: .page(.next))])
    func retainedRowsAlwaysRenderContent(phase: LoadableCollection.Phase<TestFailure>) {
        let snapshot = Snapshot(items: [Row(1)], phase: phase, hasLoaded: true)
        let presentation = LoadableUI.Presentation(snapshot: snapshot)
        #expect(presentation.state == .content)
        if case .refreshing = phase { #expect(presentation.isRefreshing) }
        else { #expect(!presentation.isRefreshing) }
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func emptyContinuationIsContent(direction: LoadableCollection.Direction) {
        let snapshot = Snapshot.loaded([], nextCursor: direction == .next ? 1 : nil,
                                       previousCursor: direction == .previous ? 1 : nil)
        #expect(LoadableUI.Presentation(snapshot: snapshot).state == .content)
    }

    @Test(arguments: [LoadableCollection.Operation.reload, .page(.next), .page(.previous)])
    func failureWithoutRowsIsFullSurface(operation: LoadableCollection.Operation) {
        let snapshot = Snapshot(items: [], phase: .failed(.offline, operation: operation),
                                nextCursor: 1, hasLoaded: true)
        #expect(LoadableUI.Presentation(snapshot: snapshot).state == .failed)
    }

    @Test(arguments: [LoadableCollection.Phase<TestFailure>.refreshing, .loadingPage(.next), .loadingPage(.previous)])
    func emptyActiveRequestIsLoading(phase: LoadableCollection.Phase<TestFailure>) {
        let snapshot = Snapshot(items: [], phase: phase, nextCursor: 1, hasLoaded: true)
        #expect(LoadableUI.Presentation(snapshot: snapshot).state == .loading)
    }
}
