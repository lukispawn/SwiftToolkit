#if DEBUG
import Foundation

// Adapted from Pentacomp's Loadable demos. These fixtures never access a server.
struct DemoItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?

    var initials: String {
        title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

enum DemoFailure: LocalizedError, Equatable {
    case noConnection
    case timeout

    var errorDescription: String? {
        switch self {
        case .noConnection: "Could not connect. This is an intentional demo failure."
        case .timeout: "The request timed out. Retrying this request will succeed."
        }
    }
}

enum DemoLatency: String, CaseIterable, Identifiable, Sendable {
    case instant = "No delay"
    case normal = "0.6 s"
    case slow = "1.5 s"
    case verySlow = "3 s"

    var id: String { rawValue }
    var duration: Duration {
        switch self {
        case .instant: .zero
        case .normal: .milliseconds(600)
        case .slow: .milliseconds(1500)
        case .verySlow: .seconds(3)
        }
    }
}

extension LoadableCollection.Phase {
    var demoDescription: String {
        switch self {
        case .idle: "Ready"
        case .loading: "Initial load"
        case .refreshing: "Refreshing"
        case .loadingPage(.next): "Next page"
        case .loadingPage(.previous): "Previous page"
        case .failed(_, .reload): "Load failed"
        case .failed(_, .page): "Page failed"
        }
    }
}

extension LoadableValue.Phase {
    var demoDescription: String {
        switch self {
        case .idle: "Ready"
        case .loading: "Initial load"
        case .refreshing: "Refreshing"
        case .failed: "Load failed"
        }
    }
}
#endif
