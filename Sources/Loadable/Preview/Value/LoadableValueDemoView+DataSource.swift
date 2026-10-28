#if DEBUG
import Foundation

struct DemoProfile: Sendable, Equatable {
    var name = "Alice Smith"
    var role = "Internal medicine specialist"
    var city = "London"
    var revision: Int
}

extension LoadableValueDemoView {
    actor DataSource: LoadableValueSource {
        typealias Value = DemoProfile
        typealias Query = Never

        enum Behavior: String, CaseIterable, Identifiable, Sendable {
            case success = "Successful requests"
            case failsFirst = "First-load failure · once"
            case failsRefresh = "Refresh failure · once"
            var id: String { rawValue }
        }

        private let behavior: Behavior
        private let delay: Duration
        private var revision = 0
        private var failedFirst = false
        private var failedRefresh = false

        init(behavior: Behavior = .success, delay: Duration = .milliseconds(600)) {
            self.behavior = behavior
            self.delay = delay
        }

        func fetch(query: Never?) async throws -> DemoProfile {
            try Task.checkCancellation()
            try await Task.sleep(for: delay)
            if behavior == .failsFirst, !failedFirst {
                failedFirst = true
                throw DemoFailure.noConnection
            }
            if behavior == .failsRefresh, revision > 0, !failedRefresh {
                failedRefresh = true
                throw DemoFailure.timeout
            }
            revision += 1
            return DemoProfile(revision: revision)
        }
    }
}
#endif
