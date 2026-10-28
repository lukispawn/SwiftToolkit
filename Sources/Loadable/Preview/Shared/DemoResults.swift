#if DEBUG
import SwiftUI

/// Pentacomp's results surface adapted to Observation and retained-error snapshots.
struct DemoResults<Source: LoadableCollectionSource>: View where Source.Item == DemoItem {
    let store: LoadableCollectionStore<Source>
    var loadingTitle = "Loading results"
    var emptyTitle = "No results"
    var gateMessage: String?
    var pendingQuery: String?
    var debouncePending: Bool?
    var showsLoadingWhileWaiting = false
    var allowsAutomaticPrefetch = true

    var body: some View {
        Group {
            if let gateMessage {
                DemoMessage(title: "Start with a search", systemImage: "magnifyingglass",
                            detail: gateMessage)
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DemoStatusBar(
                phase: store.snapshot.phase.demoDescription,
                isLoading: store.snapshot.phase.isLoading, hasError: store.lastError != nil,
                itemCount: store.items.count, canLoadMore: store.canLoadMore,
                query: store.snapshot.query as? String, pendingQuery: pendingQuery,
                debouncePending: debouncePending,
                cursor: store.snapshot.nextCursor.map { String(describing: $0) }
            )
        }
    }

    private var list: some View {
        LoadableUI.List(store: store, configuration: .init(
            pagination: allowsAutomaticPrefetch ? .automatic : .manual,
            startsAutomatically: false
        )) { item in
            DemoRow(item: item)
        }
        .loading { ProgressView(loadingTitle).padding(24) }
        .empty {
            DemoMessage(title: emptyTitle, systemImage: "tray",
                        detail: "Change the scenario or try a different search.")
        }
        .failure { failure in
            if store.items.isEmpty {
                DemoMessage(title: "Could not load data", systemImage: "wifi.slash",
                            detail: failure.error.localizedDescription, action: failure.retry)
            } else {
                DemoErrorBanner(title: "Your results are still available",
                                detail: failure.error.localizedDescription) { failure.retry?() }
            }
        }
        .idle { context in
            DemoMessage(title: "Ready to load", systemImage: "arrow.down.circle",
                        detail: "Loading has been paused.", actionTitle: "Load data", action: context.reload)
        }
        .pagination { pagination in
            LoadableUI.Components.Pagination(context: pagination)
        }
        .listStyle(.plain)
        .overlay {
            if showsLoadingWhileWaiting, debouncePending == true {
                ProgressView("Waiting for you to finish typing…")
                    .padding(20).background(.regularMaterial, in: .rect(cornerRadius: 18))
            }
        }
    }
}

#Preview("Results · constant list") {
    DemoResults(store: LoadableCollectionStore(items: [
        DemoItem(id: "1", title: "Alice Smith", subtitle: "Member ID 1000001")
    ]))
    .demoPreviewSize(width: 420, height: 500)
}
#endif
