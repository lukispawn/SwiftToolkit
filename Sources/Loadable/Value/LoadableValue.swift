public enum LoadableValue {
    /// Unlike Value?, this distinguishes a successfully loaded nil from missing data.
    public enum Content<Value: Sendable>: Sendable {
        case missing
        case value(Value)
    }

    public enum Phase<Failure: Error>: Sendable {
        case idle
        case loading
        case refreshing
        case failed(Failure)

        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing: true
            default: false
            }
        }

        public var error: Failure? {
            if case .failed(let error) = self { error } else { nil }
        }
    }

    public struct Snapshot<Value: Sendable, Failure: Error, Query: Sendable & Equatable>: Sendable {
        public internal(set) var content: Content<Value>
        public internal(set) var phase: Phase<Failure>
        public internal(set) var query: Query?

        public init(content: Content<Value> = .missing, phase: Phase<Failure> = .idle, query: Query? = nil) {
            self.content = content
            self.phase = phase
            self.query = query
        }

        public var hasValue: Bool {
            if case .value = content { true } else { false }
        }

        public var value: Value? {
            switch content {
            case .missing: nil
            case .value(let value): .some(value)
            }
        }

        public static var idle: Self { .init() }
        public static var loading: Self { .init(phase: .loading) }

        public static func loaded(_ value: Value, query: Query? = nil) -> Self {
            .init(content: .value(value), query: query)
        }
    }
}

extension LoadableValue.Content: Equatable where Value: Equatable {}
extension LoadableValue.Phase: Equatable where Failure: Equatable {}
extension LoadableValue.Snapshot: Equatable where Value: Equatable, Failure: Equatable {}
