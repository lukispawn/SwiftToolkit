import Testing
@testable import LoadableModel

// MARK: - Mock Store for Testing

@MainActor
final class MockLoadableStore: LoadableModelSupport {
    typealias LoadedData = String

    var loadState: LoadableState

    init(loadState: LoadableState) {
        self.loadState = loadState
    }

    func onTask() async {
        // Mock implementation
    }

    func loadInBackground(setting: RefreshSettings) async throws {
        // Mock implementation
    }

    func load(setting: ReloadSettings) async throws -> String {
        // Mock implementation
        return "mock data"
    }

    @available(*, deprecated, renamed: "loadInBackground")
    func refresh(setting: RefreshSettings) async throws {
        // Mock implementation
    }
}

// MARK: - LoadableState Merge Tests

@Suite("LoadableState Merge Tests")
struct LoadableStateMergeTests {

    @Test("Empty array returns notRequested")
    @MainActor
    func testEmptyArray() async throws {
        let result = LoadableState.mergeStates(items: [])
        #expect(result == .notRequested)
    }

    @Test("All loaded returns loaded")
    @MainActor
    func testAllLoaded() async throws {
        let stores = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loaded)
        ]

        let result = LoadableState.mergeStates(items: stores)
        #expect(result == .loaded)
    }

    @Test("Any error returns failed with first error")
    @MainActor
    func testAnyError() async throws {
        struct TestError1: Error, Equatable {}
        struct TestError2: Error, Equatable {}

        let stores = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .failed(TestError1())),
            MockLoadableStore(loadState: .failed(TestError2())),
            MockLoadableStore(loadState: .loading)
        ]

        let result = LoadableState.mergeStates(items: stores)

        // Verify it's failed state
        #expect(result.isError())

        // Verify it's the first error
        if case .failed(let error) = result {
            #expect(error is TestError1)
        } else {
            Issue.record("Expected failed state")
        }
    }

    @Test("Any loading returns loading (when no errors)")
    @MainActor
    func testAnyLoading() async throws {
        let stores = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loading),
            MockLoadableStore(loadState: .notRequested)
        ]

        let result = LoadableState.mergeStates(items: stores)
        #expect(result == .loading)
    }

    @Test("All notRequested returns notRequested")
    @MainActor
    func testAllNotRequested() async throws {
        let stores = [
            MockLoadableStore(loadState: .notRequested),
            MockLoadableStore(loadState: .notRequested),
            MockLoadableStore(loadState: .notRequested)
        ]

        let result = LoadableState.mergeStates(items: stores)
        #expect(result == .notRequested)
    }

    @Test("Variadic version works correctly")
    @MainActor
    func testVariadicVersion() async throws {
        let store1 = MockLoadableStore(loadState: .loaded)
        let store2 = MockLoadableStore(loadState: .loaded)
        let store3 = MockLoadableStore(loadState: .loaded)

        let result = LoadableState.mergeStates(store1, store2, store3)
        #expect(result == .loaded)
    }

    @Test("Priority: loaded > error > loading > notRequested")
    @MainActor
    func testPriorityLogic() async throws {
        struct TestError: Error {}

        // Test error priority over loading and notRequested
        let storesWithError = [
            MockLoadableStore(loadState: .loading),
            MockLoadableStore(loadState: .failed(TestError())),
            MockLoadableStore(loadState: .notRequested)
        ]
        let resultWithError = LoadableState.mergeStates(items: storesWithError)
        #expect(resultWithError.isError())

        // Test loading priority over notRequested (no error)
        let storesWithLoading = [
            MockLoadableStore(loadState: .loading),
            MockLoadableStore(loadState: .notRequested),
            MockLoadableStore(loadState: .notRequested)
        ]
        let resultWithLoading = LoadableState.mergeStates(items: storesWithLoading)
        #expect(resultWithLoading == .loading)

        // Test loaded requires ALL loaded
        let storesPartiallyLoaded = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .notRequested)
        ]
        let resultPartial = LoadableState.mergeStates(items: storesPartiallyLoaded)
        #expect(resultPartial == .notRequested)
    }

    @Test("Single store returns its state")
    @MainActor
    func testSingleStore() async throws {
        let loadedStore = MockLoadableStore(loadState: .loaded)
        #expect(LoadableState.mergeStates(items: [loadedStore]) == .loaded)

        let loadingStore = MockLoadableStore(loadState: .loading)
        #expect(LoadableState.mergeStates(items: [loadingStore]) == .loading)

        let notRequestedStore = MockLoadableStore(loadState: .notRequested)
        #expect(LoadableState.mergeStates(items: [notRequestedStore]) == .notRequested)

        struct TestError: Error {}
        let failedStore = MockLoadableStore(loadState: .failed(TestError()))
        #expect(LoadableState.mergeStates(items: [failedStore]).isError())
    }

    @Test("Mixed state scenarios")
    @MainActor
    func testMixedScenarios() async throws {
        struct TestError: Error {}

        // Scenario 1: Some loaded, some not requested (no loading/error)
        let scenario1 = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .notRequested)
        ]
        #expect(LoadableState.mergeStates(items: scenario1) == .notRequested)

        // Scenario 2: All states present (error should win)
        let scenario2 = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loading),
            MockLoadableStore(loadState: .failed(TestError())),
            MockLoadableStore(loadState: .notRequested)
        ]
        #expect(LoadableState.mergeStates(items: scenario2).isError())

        // Scenario 3: Loaded + Loading (loading should prevent loaded)
        let scenario3 = [
            MockLoadableStore(loadState: .loaded),
            MockLoadableStore(loadState: .loading)
        ]
        #expect(LoadableState.mergeStates(items: scenario3) == .loading)
    }
}
