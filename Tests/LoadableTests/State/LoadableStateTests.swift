import Testing
import Loadable

private enum StateCase: CaseIterable, Sendable {
    case idle, loading, loaded, failed, refreshing, refreshFailed, nextPage, previousPage, pageFailed, unloadedPage

    var state: LoadableState {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case .loaded: .loaded
        case .failed: .init(hasLoaded: false, error: TestFailure.offline)
        case .refreshing: .init(hasLoaded: true, activity: .refreshing)
        case .refreshFailed: .init(hasLoaded: true, error: TestFailure.rejected)
        case .nextPage: .init(hasLoaded: true, activity: .loadingPage(.next))
        case .previousPage: .init(hasLoaded: true, activity: .loadingPage(.previous))
        case .pageFailed: .init(hasLoaded: true, error: TestFailure.rejected, operation: .page(.next))
        case .unloadedPage: .init(hasLoaded: false, activity: .loadingPage(.next))
        }
    }

    var isReady: Bool {
        switch self {
        case .loaded, .refreshing, .refreshFailed, .nextPage, .previousPage, .pageFailed: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .loading, .refreshing, .nextPage, .previousPage, .unloadedPage: true
        default: false
        }
    }
}

@Suite("Common loading state and merge")
struct LoadableStateTests {
    @Test(arguments: StateCase.allCases, StateCase.allCases)
    fileprivate func everyPairUsesReadinessAndBlockingFailurePrecedence(left: StateCase, right: StateCase) {
        let result = LoadableState.merge([left.state, right.state])
        let expected: LoadableState.Phase
        if left.isReady && right.isReady { expected = .loaded }
        else if left == .failed || right == .failed { expected = .failed }
        else if left.isActive || right.isActive { expected = .loading }
        else { expected = .idle }
        #expect(result.phase == expected)
        #expect(result.hasLoaded == (left.isReady && right.isReady))
        #expect(result.isLoading == (left.isActive || right.isActive))
        #expect(result.storeCount == 2)
        #expect(result.loadedStoreCount == [left, right].filter(\.isReady).count)
    }

    @Test func emptyGroupIsIdleAndNotVacuouslyLoaded() {
        let state = LoadableState.merge([])
        #expect(state.phase == .idle)
        #expect(!state.hasLoaded)
        #expect(!state.isLoading)
        #expect(!state.isRefreshing)
        #expect(!state.isLoadingPage)
        #expect(state.errors.isEmpty)
        #expect(state.storeCount == 0)
        #expect(state.loadedStoreCount == 0)
    }

    @Test func mixedFailuresKeepAllErrorsAndTheirOriginalSeverityAndOperation() {
        let result = LoadableState.merge([
            .init(hasLoaded: true, error: TestFailure.rejected, operation: .page(.previous)),
            .loading,
            .init(hasLoaded: false, error: TestFailure.offline),
            .init(hasLoaded: true, error: TestFailure.offline)
        ])
        #expect(result.phase == .failed)
        #expect(result.isLoading)
        #expect(result.errors.compactMap { $0 as? TestFailure } == [.rejected, .offline, .offline])
        #expect(result.failures.map(\.isBlocking) == [false, true, false])
        #expect(result.failures.map(\.operation) == [.page(.previous), .load, .load])
        #expect(result.blockingFailures.count == 1)
        #expect(result.blockingFailures.first?.error as? TestFailure == .offline)
    }

    @Test func mergingGroupsIsAssociativeAndPreservesLeafCountsAndActivities() {
        let a: LoadableState = .init(hasLoaded: true, activity: .refreshing, error: TestFailure.offline)
        let b: LoadableState = .init(hasLoaded: true, activity: .loadingPage(.previous))
        let c: LoadableState = .init(hasLoaded: false, error: TestFailure.rejected)
        let flat = LoadableState.merge([a, b, c])
        for nested in [LoadableState.merge([.merge([a, b]), c]), .merge([a, .merge([b, c])])] {
            #expect(nested.phase == flat.phase)
            #expect(nested.storeCount == 3)
            #expect(nested.loadedStoreCount == 2)
            #expect(nested.isRefreshing)
            #expect(nested.isLoadingPage)
            #expect(nested.isLoading)
            #expect(nested.errors.compactMap { $0 as? TestFailure } == [.offline, .rejected])
            #expect(nested.failures.map(\.isBlocking) == [false, true])
        }
    }

    @Test func emptyNestedGroupsAreNeutralAndDoNotBecomePhantomStores() {
        let state = LoadableState.merge([.merge([]), .loaded, .merge([])])
        #expect(state.phase == .loaded)
        #expect(state.storeCount == 1)
        #expect(state.loadedStoreCount == 1)
        #expect(LoadableState.merge([.merge([]), .merge([])]).phase == .idle)
    }

    @Test(arguments: StateCase.allCases)
    fileprivate func reorderingDoesNotChangeReadinessOrActivity(sample: StateCase) {
        let a = LoadableState.merge([.loaded, sample.state, .loading])
        let b = LoadableState.merge([.loading, .loaded, sample.state])
        #expect(a.phase == b.phase)
        #expect(a.loadedStoreCount == b.loadedStoreCount)
        #expect(a.isLoading == b.isLoading)
        #expect(a.isRefreshing == b.isRefreshing)
        #expect(a.isLoadingPage == b.isLoadingPage)
    }

    @Test func retainedFailureDoesNotBlockButMissingInactiveSiblingPreventsReadiness() {
        let result = LoadableState.merge([.init(hasLoaded: true, error: TestFailure.offline), .idle])
        #expect(result.phase == .idle)
        #expect(!result.hasLoaded)
        #expect(result.errors.count == 1)
        #expect(result.blockingFailures.isEmpty)
    }
}
