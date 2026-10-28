import Foundation

extension LoadableUI {
    /// View-owned guard shared by header/footer triggers; it never owns a request task.
    @MainActor
    struct AutomaticPagination<Source: LoadableCollectionSource> {
        private var sessionID: UUID?
        private var requestedCursors: [Source.Cursor] = []
        private var edgeBeforeRequest: Source.Item.ID?
        private var hasRequested = false

        func needsManualContinuation(_ context: PaginationContext<Source>) -> Bool {
            guard sessionID == context.sessionID, hasRequested,
                  context.state == .available, let cursor = context.cursor else { return false }
            return requestedCursors.contains(cursor) || context.edgeID == edgeBeforeRequest
        }

        @discardableResult
        mutating func loadIfNeeded(_ context: PaginationContext<Source>, isVisible: Bool,
                                   willLoad: () -> Void = {}) -> Bool {
            guard isVisible, context.automaticallyLoads, context.state == .available,
                  !needsManualContinuation(context) else { return false }
            recordRequest(context)
            willLoad()
            context.load()
            return true
        }

        mutating func recordRequest(_ context: PaginationContext<Source>) {
            guard let cursor = context.cursor else { return }
            if sessionID != context.sessionID {
                sessionID = context.sessionID
                requestedCursors.removeAll()
            }
            if !requestedCursors.contains(cursor) { requestedCursors.append(cursor) }
            edgeBeforeRequest = context.edgeID
            hasRequested = true
        }
    }
}

extension LoadableUI.PaginationContext {
    var automaticallyLoads: Bool { collection.configuration.pagination == .automatic }
    var sessionID: UUID { collection.store.paginationSessionID }
    var cursor: Source.Cursor? { collection.store.snapshot.cursor(for: direction) }
    var edgeID: Source.Item.ID? {
        direction == .previous ? collection.items.first?.id : collection.items.last?.id
    }
}
