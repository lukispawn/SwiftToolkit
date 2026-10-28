#if DEBUG
extension LoadableChat {
    typealias Store = LoadableCollectionStore<Source>

    struct Configuration: Equatable {
        var scenario: Scenario = .normal
        var window: Window = .middle
        var latency: DemoLatency = .normal
    }

    enum Scenario: String, CaseIterable, Identifiable {
        case normal = "Normal conversation"
        case emptyConversation = "Empty conversation"
        case pageFailures = "Older and newer pages fail once"
        case sendFailure = "First send fails once"
        case initialFailure = "First load fails once"
        var id: String { rawValue }
        var failures: Set<Failure> {
            switch self {
            case .normal, .emptyConversation: []
            case .pageFailures: [.older, .newer]
            case .sendFailure: [.send]
            case .initialFailure: [.initial]
            }
        }
        var seedCount: Int { self == .emptyConversation ? 0 : 90 }
    }

    enum Window: String, CaseIterable, Identifiable {
        case middle = "Middle of history"
        case latest = "Latest messages"
        var id: String { rawValue }
        var query: Query { self == .latest ? .latest : .around(45) }
    }
}
#endif
