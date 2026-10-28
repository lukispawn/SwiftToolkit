#if DEBUG
import SwiftUI

/// Advanced search scenarios adapted from Pentacomp: minimum length, empty query,
/// pending debounce, optional waiting indicator, paginated results and diagnostics.
public struct LoadableCollectionSearchDemoView: View {
    @State private var model: ViewModel
    private let showsLoadingWhileWaiting: Bool

    public init(
        minimumLength: Int = 2, debounce: Duration = .milliseconds(400),
        showsAllWhenEmpty: Bool = true, showsLoadingWhileWaiting: Bool = false,
        responseDelay: Duration = .milliseconds(1500)
    ) {
        self.showsLoadingWhileWaiting = showsLoadingWhileWaiting
        _model = State(initialValue: ViewModel(
            minimumLength: minimumLength, debounce: debounce,
            showsAllWhenEmpty: showsAllWhenEmpty,
            responseDelay: responseDelay
        ))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                introduction
                Divider()
                DemoResults(
                    store: model.store, loadingTitle: "Searching for people…",
                    emptyTitle: "No matching people", gateMessage: gateMessage,
                    pendingQuery: model.debouncer.pendingQuery, debouncePending: model.debouncer.isWaiting,
                    showsLoadingWhileWaiting: showsLoadingWhileWaiting
                )
            }
            .navigationTitle("Search")
            .searchable(text: $model.text, prompt: "First or last name")
            .onSubmit(of: .search) { model.submitNow() }
            .toolbar {
                Button("Search now", systemImage: "magnifyingglass") { model.submitNow() }
                    .disabled(gateMessage != nil)
                Button("Cancel", systemImage: "pause") { model.stop() }
            }
        }
        .tint(.indigo)
        .task { model.startIfNeeded() }
        .onDisappear { model.stop() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            DemoIntroduction(category: "Search + debounce", title: "Find a person",
                             detail: "120 people, paginated results and case- and accent-insensitive search.")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    queryButton("Smith", query: "Smith")
                    queryButton("Ignore accents", query: "garcia")
                    queryButton("No results", query: "xyz")
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
    }

    private func queryButton(_ title: String, query: String) -> some View {
        Button(title) {
            model.text = query
            model.submitNow()
        }
        .buttonStyle(.bordered).controlSize(.small)
    }

    private var gateMessage: String? {
        guard case .tooShort(let count) = model.requirement else { return nil }
        return "Enter at least \(count) characters to search for people."
    }
}

#Preview("Search · show all for an empty query") {
    LoadableCollectionSearchDemoView().demoPreviewSize(width: 420, height: 800)
}
#Preview("Search · minimum 2 characters") {
    LoadableCollectionSearchDemoView(showsAllWhenEmpty: false).demoPreviewSize(width: 420, height: 800)
}
#Preview("Search · waiting indicator during debounce") {
    LoadableCollectionSearchDemoView(debounce: .seconds(1), showsAllWhenEmpty: false,
                                     showsLoadingWhileWaiting: true).demoPreviewSize(width: 420, height: 800)
}
#Preview("Search · wide window") {
    LoadableCollectionSearchDemoView().demoPreviewSize(width: 760, height: 760)
}
#endif
