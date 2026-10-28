import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Collection search integration", .timeLimit(.minutes(1)))
struct CollectionSearchTests {
    typealias Search = LoadableCollectionSearch<ControlledCollectionSource>

    @Test func configuredInitialTextIsTrimmedAndMapped() async throws {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source)
        let search = Search(store: store, initialText: "  alice  ", makeQuery: { $0.uppercased() })
        #expect(search.text == "  alice  ")
        #expect(search.requirement == .satisfied(query: "ALICE"))
        search.startIfNeeded()
        let request = try #require(store.requestTask)
        search.startIfNeeded()
        await source.waitForCalls(1)
        #expect(await source.calls.first?.query == "ALICE")
        await source.complete(0, .success(.init(items: [Row(1)])))
        _ = await request.result
        search.startIfNeeded()
        #expect(await source.calls.count == 1)
    }

    @Test(arguments: [true, false])
    func emptyInputGateRespectsPolicy(showsAll: Bool) async throws {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source)
        let search = Search(store: store, showsAllWhenEmpty: showsAll)
        search.startIfNeeded()
        search.submitNow()
        if showsAll {
            let task = try #require(store.requestTask)
            // Immediate submission supersedes a scheduled initial request before the source runs.
            await source.waitForCalls(1)
            await source.complete(0, .success(.init(items: [])))
            _ = await task.result
            #expect(search.requirement == .satisfied(query: ""))
        } else {
            #expect(store.requestTask == nil)
            #expect(await source.calls.isEmpty)
            #expect(search.requirement == .tooShort(minimumLength: 2))
        }
    }

    @Test func minimumLengthIsClampedAndInputIsObservable() async {
        let search = Search(store: CollectionStore(source: ControlledCollectionSource()),
                            minimumLength: -1, showsAllWhenEmpty: false)
        #expect(search.minimumLength == 1)
        await confirmation("Search requirement is observed") { changed in
            withObservationTracking { _ = search.requirement } onChange: { changed() }
            search.text = " A "
        }
        #expect(search.requirement == .satisfied(query: "A"))
        search.stop()
    }

    @Test func newTextCancelsOldFetchBeforeDebounceCommits() async throws {
        let source = ControlledCollectionSource()
        let clock = ControlledClock()
        let store = CollectionStore(source: source)
        let search = Search(store: store, debounce: .seconds(1), clock: clock,
                            initialText: "Alice", makeQuery: { $0 })
        search.startIfNeeded()
        let old = try #require(store.requestTask)
        await source.waitForCalls(1)
        search.text = "James"
        #expect(old.isCancelled)
        #expect(store.requestTask == nil)
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search.debouncer.scheduledTask)
        search.startIfNeeded()
        #expect(store.requestTask == nil)
        await source.complete(0, .success(.init(items: [Row(99)])))
        _ = await old.result
        #expect(store.items.isEmpty)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        let current = try #require(store.requestTask)
        await source.waitForCalls(2)
        #expect(await source.calls.last?.query == "James")
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await current.result
        #expect(store.items == [Row(2)])
    }

    @Test func invalidInputInvalidatesEvenNonCooperativeDebounceWakeup() async throws {
        let source = ControlledCollectionSource()
        let clock = ControlledClock()
        let store = CollectionStore(source: source)
        let search = Search(store: store, debounce: .seconds(1), clock: clock,
                            showsAllWhenEmpty: false, makeQuery: { $0 })
        search.text = "Alice"
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search.debouncer.scheduledTask)
        search.text = " A "
        #expect(search.requirement == .tooShort(minimumLength: 2))
        #expect(!search.debouncer.isWaiting)
        search.submitNow()
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        #expect(await source.calls.isEmpty)
        #expect(store.requestTask == nil)
    }

    @Test func immediateSubmissionPreventsDuplicateDebouncedRequest() async throws {
        let source = ControlledCollectionSource()
        let clock = ControlledClock()
        let store = CollectionStore(source: source)
        let search = Search(store: store, debounce: .seconds(1), clock: clock, makeQuery: { $0 })
        search.text = "Alice"
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search.debouncer.scheduledTask)
        search.submitNow()
        let request = try #require(store.requestTask)
        await source.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        await source.complete(0, .success(.init(items: [Row(1)])))
        _ = await request.result
        #expect(await source.calls.count == 1)
    }

    @Test func debouncedEquivalentQueryKeepsSuccessfulSession() async throws {
        let (store, source) = try await seededCollection()
        let clock = ControlledClock()
        let search = Search(store: store, minimumLength: 1, debounce: .seconds(1), clock: clock,
                            initialText: "A", makeQuery: { $0 })
        search.text = " A "
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search.debouncer.scheduledTask)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        #expect(store.items == [Row(1)])
        #expect(store.canLoadMore)
        #expect(store.requestTask == nil)
        #expect(await source.calls.count == 1)
    }

    @Test func leavingAndReenteringGateAllowsSameQueryAgain() async throws {
        let (store, source) = try await seededCollection()
        let search = Search(store: store, minimumLength: 2, showsAllWhenEmpty: false)
        search.text = "Alice"
        search.submitNow()
        let first = try #require(store.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await first.result
        search.text = "A"
        search.text = "Alice"
        search.submitNow()
        let repeated = try #require(store.requestTask)
        await source.waitForCalls(3)
        await source.complete(2, .success(.init(items: [Row(3)])))
        _ = await repeated.result
        #expect(store.items == [Row(3)])
        #expect(store.snapshot.query == "Alice")
    }

    @Test func stopCancelsPendingDebounceAndEndsPaginationSession() async throws {
        let (store, source) = try await seededCollection()
        let clock = ControlledClock()
        let search = Search(store: store, debounce: .seconds(1), clock: clock, makeQuery: { $0 })
        search.text = "Alice"
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search.debouncer.scheduledTask)
        search.stop()
        #expect(!store.canLoadMore)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        #expect(await source.calls.count == 1)
    }

    @Test func releasingSearchDoesNotRetainDebouncerOrCancelSharedStore() async throws {
        let (store, source) = try await seededCollection()
        let clock = ControlledClock()
        var search: Search? = .init(store: store, debounce: .seconds(1), clock: clock, makeQuery: { $0 })
        let weakSearch = WeakReference(search)
        let weakDebouncer = WeakReference(search?.debouncer)
        search?.text = "Alice"
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(search?.debouncer.scheduledTask)
        search = nil
        #expect(weakSearch.value == nil)
        #expect(weakDebouncer.value == nil)
        #expect(store.canLoadMore)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        #expect(await source.calls.count == 1)
    }
}
