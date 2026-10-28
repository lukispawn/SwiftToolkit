#if DEBUG
import SwiftUI

/// The non-paginated Pentacomp example, kept separate from the paginated demo.
public struct LoadableCollectionSinglePageDemoView: View {
    @State private var store: LoadableCollectionStore<DataSource>

    public init() { self.init(itemCount: 16) }

    init(itemCount: Int) {
        _store = State(initialValue: .init(source: DataSource(itemCount: itemCount)))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DemoIntroduction(category: "Single-page collection", title: "All items at once",
                                 detail: "One request, no cursor. Pull to refresh or use the refresh button.")
                    .padding(20)
                Divider()
                DemoResults(store: store, emptyTitle: "No cities")
            }
            .navigationTitle("Cities")
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { store.refreshInBackground() }
            }
        }
        .tint(.indigo)
        .task { store.startIfNeeded() }
        .onDisappear { store.cancel() }
    }

    actor DataSource: LoadableCollectionSource {
        typealias Item = DemoItem
        typealias Cursor = Never
        typealias Query = Never
        private let itemCount: Int
        private let delay: Duration

        init(itemCount: Int = 16, delay: Duration = .milliseconds(600)) {
            self.itemCount = max(0, itemCount)
            self.delay = delay
        }

        func fetchPage(query: Never?, cursor: Never?, direction: LoadableCollection.Direction) async throws -> Page {
            try Task.checkCancellation()
            try await Task.sleep(for: delay)
            let names = [
                "Bath", "Birmingham", "Brighton", "Bristol", "Cambridge", "Canterbury",
                "Chester", "Durham", "Exeter", "Leeds", "Liverpool", "London",
                "Manchester", "Newcastle", "Oxford", "York"
            ]
            return .init(items: names.prefix(itemCount).map { .init(id: $0, title: $0, subtitle: "United Kingdom") })
        }
    }
}

#Preview("Full list") { LoadableCollectionSinglePageDemoView().demoPreviewSize(width: 420, height: 780) }
#Preview("Empty list without pagination") {
    LoadableCollectionSinglePageDemoView(itemCount: 0).demoPreviewSize(width: 420, height: 680)
}
#endif
