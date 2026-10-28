#if DEBUG
import Observation

extension LoadableStateDemoView {
    enum Scenario: String, CaseIterable, Identifiable {
        case success = "All stores succeed"
        case initialFailure = "Initial profile failure · once"
        case refreshFailure = "Profile refresh failure · once"
        case pageFailure = "Next-page failure · once"
        var id: String { rawValue }
    }

    @MainActor @Observable
    final class Model: LoadableStateProviding {
        enum FrozenState { case loaded, loading, failed, refreshFailed, pageFailed }
        typealias Profile = LoadableValueStore<LoadableValueDemoView.DataSource>
        typealias Permissions = LoadableValueStore<LoadableValue.OperationSource<String, Never, any Error>>
        typealias People = LoadableCollectionStore<LoadableCollectionBasicDemoView.DataSource>

        let profile: Profile
        let permissions: Permissions
        let people: People
        let isFrozen: Bool

        var loadableState: LoadableState { .merge(stores: [profile, permissions, people]) }

        init(scenario: Scenario, frozen: FrozenState? = nil) {
            isFrozen = frozen != nil
            let profileBehavior: LoadableValueDemoView.DataSource.Behavior
            switch scenario {
            case .initialFailure: profileBehavior = .failsFirst
            case .refreshFailure: profileBehavior = .failsRefresh
            default: profileBehavior = .success
            }
            let profileSource = LoadableValueDemoView.DataSource(behavior: profileBehavior)
            let peopleSource = LoadableCollectionBasicDemoView.DataSource(
                behavior: scenario == .pageFailure ? .failsOnNextPage : .success,
                delay: .milliseconds(1400), pageCount: 3, itemsPerPage: 3
            )
            let permissionsSource = LoadableValue.OperationSource<String, Never, any Error> { _ in
                try await Task.sleep(for: .seconds(1))
                return "Read and edit"
            }
            if let frozen {
                var profileSnapshot = Profile.Snapshot.loaded(DemoProfile(revision: 1))
                var peopleSnapshot = People.Snapshot.loaded([
                    DemoItem(id: "1", title: "James Johnson", subtitle: "Member ID 1000001"),
                    DemoItem(id: "2", title: "Catherine Wilson", subtitle: "Member ID 1000002")
                ], nextCursor: 1)
                switch frozen {
                case .loaded: break
                case .loading: profileSnapshot = .loading
                case .failed: profileSnapshot = .init(phase: .failed(DemoFailure.noConnection))
                case .refreshFailed: profileSnapshot.phase = .failed(DemoFailure.timeout)
                case .pageFailed: peopleSnapshot.phase = .failed(DemoFailure.timeout, operation: .page(.next))
                }
                profile = .init(source: profileSource, constantSnapshot: profileSnapshot)
                people = .init(source: peopleSource, constantSnapshot: peopleSnapshot)
                permissions = .init(source: permissionsSource, constantSnapshot: .loaded("Read and edit"))
            } else {
                profile = .init(source: profileSource)
                people = .init(source: peopleSource)
                permissions = .init(source: permissionsSource)
            }
        }

        func startIfNeeded() {
            profile.startIfNeeded()
            permissions.startIfNeeded()
            people.startIfNeeded()
        }

        func refreshAll() {
            profile.refreshInBackground()
            permissions.refreshInBackground()
            people.refreshInBackground()
        }

        func reloadAll() {
            profile.reload()
            permissions.reload()
            people.reload()
        }

        func retryFailed() {
            profile.retry()
            permissions.retry()
            people.retry()
        }

        func cancelAll() {
            profile.cancelRequest()
            permissions.cancelRequest()
            people.cancelRequest()
        }
    }
}
#endif
