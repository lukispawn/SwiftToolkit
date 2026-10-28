extension LoadableUI {
    /// Presentation policy only. Request and merge policies remain on the store.
    public struct Configuration: Sendable, Equatable {
        public enum Pagination: Sendable, Equatable {
            /// Prefetch next rows and load either direction when its Pagination edge is visible.
            case automatic
            case manual
            case disabled
        }

        public var pagination: Pagination
        public var isRefreshable: Bool
        public var startsAutomatically: Bool

        public init(pagination: Pagination = .automatic, isRefreshable: Bool = true,
                    startsAutomatically: Bool = true) {
            self.pagination = pagination
            self.isRefreshable = isRefreshable
            self.startsAutomatically = startsAutomatically
        }
    }
}
