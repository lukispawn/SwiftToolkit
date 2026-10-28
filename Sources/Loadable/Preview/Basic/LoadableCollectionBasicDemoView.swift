#if DEBUG
import SwiftUI

/// Interactive pagination scenarios ported from Pentacomp, using Observation.
public struct LoadableCollectionBasicDemoView: View {
    @State private var store: LoadableCollectionStore<DataSource>
    @State private var behavior: DataSource.Behavior
    @State private var latency = DemoLatency.normal
    @State private var automaticPrefetch = true

    public init() { self.init(behavior: .success) }

    init(behavior: DataSource.Behavior) {
        _behavior = State(initialValue: behavior)
        _store = State(initialValue: .init(source: DataSource(behavior: behavior)))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                Divider()
                DemoResults(store: store, allowsAutomaticPrefetch: automaticPrefetch)
            }
            .navigationTitle("Paginated list")
            .toolbar {
                ToolbarItemGroup {
                    Button("Refresh", systemImage: "arrow.clockwise") { store.refreshInBackground() }
                    Button("Cancel", systemImage: "pause") { store.cancelRequest() }
                }
            }
        }
        .tint(.indigo)
        .task { store.startIfNeeded() }
        .onDisappear { store.cancel() }
        .onChange(of: behavior) { restart() }
        .onChange(of: latency) { restart() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            DemoIntroduction(category: "Collection Store", title: "Page by page",
                             detail: "Scroll, refresh and retry failed requests while keeping your results.")
            DisclosureGroup("Scenario and controls") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Scenario", selection: $behavior) {
                        ForEach(DataSource.Behavior.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Response time", selection: $latency) {
                        ForEach(DemoLatency.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Automatic pagination", isOn: $automaticPrefetch)
                    HStack {
                        Button("Start over", systemImage: "arrow.counterclockwise", action: restart)
                        Spacer()
                        if store.canLoad(.previous) {
                            Button("Previous page", systemImage: "arrow.up") { store.loadPage(.previous) }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline).padding(.top, 12)
            }
            .font(.subheadline)
        }
        .padding(20)
        .background(.background)
    }

    private func restart() {
        store.cancel()
        store = .init(source: DataSource(behavior: behavior, delay: latency.duration))
        store.start()
    }
}

#Preview("Pagination") { LoadableCollectionBasicDemoView().demoPreviewSize(width: 420, height: 780) }
#Preview("First-page failure and retry") {
    LoadableCollectionBasicDemoView(behavior: .failsOnFirstPage).demoPreviewSize(width: 420, height: 780)
}
#Preview("Next-page failure and retry") {
    LoadableCollectionBasicDemoView(behavior: .failsOnNextPage).demoPreviewSize(width: 420, height: 780)
}
#Preview("Empty list") { LoadableCollectionBasicDemoView(behavior: .empty).demoPreviewSize(width: 420, height: 780) }
#Preview("Empty intermediate page") {
    LoadableCollectionBasicDemoView(behavior: .emptyIntermediate).demoPreviewSize(width: 420, height: 780)
}
#Preview("Both directions") {
    LoadableCollectionBasicDemoView(behavior: .bidirectional).demoPreviewSize(width: 640, height: 780)
}
#endif
