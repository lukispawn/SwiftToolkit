import SwiftUI

extension LoadableUI.Components {
    /// Place at the next/previous edge of a collection, including a horizontal layout.
    /// Automatic mode loads at a visible edge; stalled/cyclic pages require explicit continuation.
    public struct Pagination<Source: LoadableCollectionSource>: View {
        private let context: LoadableUI.PaginationContext<Source>
        private let willLoad: @MainActor () -> Void
        @State private var automatic = LoadableUI.AutomaticPagination<Source>()

        public init(context: LoadableUI.PaginationContext<Source>,
                    willLoad: @escaping @MainActor () -> Void = {}) {
            self.context = context
            self.willLoad = willLoad
        }

        public var body: some View {
            switch context.state {
            case .hidden: EmptyView()
            case .available:
                if context.automaticallyLoads && !automatic.needsManualContinuation(context) {
                    automaticTrigger.id(context.sessionID)
                } else {
                    Button(context.direction == .next ? "Load more" : "Load previous", action: load)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
            case .loading:
                ProgressView(context.direction == .next ? "Loading more…" : "Loading previous…")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            case .failed:
                if let failure = failureContext { LoadableUI.Components.Failure(context: failure) }
            }
        }

        @ViewBuilder private var automaticTrigger: some View {
            if #available(iOS 18, macOS 15, *) {
                sentinel.onScrollVisibilityChange(threshold: 0.01) { isVisible in
                    automatic.loadIfNeeded(context, isVisible: isVisible, willLoad: willLoad)
                }
            } else {
                sentinel.onAppear {
                    automatic.loadIfNeeded(context, isVisible: true, willLoad: willLoad)
                }
            }
        }

        private var sentinel: some View {
            Color.clear.frame(width: 1, height: 1)
                .listRowInsets(EdgeInsets())
                .environment(\.defaultMinListRowHeight, 1)
                .accessibilityHidden(true)
        }

        private func load() {
            guard context.state == .available else { return }
            automatic.recordRequest(context)
            willLoad()
            context.load()
        }

        private var failureContext: LoadableUI.FailureContext<Source.Failure>? {
            guard let failure = context.failure, let retry = failure.retry else { return context.failure }
            return .init(error: failure.error, operation: failure.operation, retry: {
                automatic.recordRequest(context)
                willLoad()
                retry()
            })
        }
    }
}
