#if DEBUG
import SwiftUI

/// Public UI components with native List, ScrollView and grid composition.
struct LoadableCollectionLayoutDemoView: View {
    enum Layout: String, CaseIterable, Identifiable {
        case list = "List"
        case cards = "Cards"
        case grid = "Grid"
        var id: String { rawValue }
    }
    @State private var layout: Layout
    typealias Store = LoadableCollectionStore<LoadableCollectionBasicDemoView.DataSource>
    @State private var store: Store

    init(layout: Layout, snapshot: Store.Snapshot? = nil) {
        _layout = State(initialValue: layout)
        let source = LoadableCollectionBasicDemoView.DataSource()
        _store = State(initialValue: snapshot.map { Store(source: source, constantSnapshot: $0) }
                       ?? Store(source: source))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    DemoIntroduction(category: "Collection UI", title: "One store. Three layouts.",
                                     detail: "Switch between a native list, scrollable cards and an adaptive grid.")
                    Picker("Layout", selection: $layout) {
                        ForEach(Layout.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(20)
                Divider()
                content
            }
            .navigationTitle("Collection UI")
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { store.refreshInBackground() }
                    .disabled(!store.canReload)
                Button("Reload", systemImage: "arrow.down.circle") { store.reload() }
                    .disabled(!store.canReload)
            }
        }
        .tint(.indigo)
    }

    private var content: some View {
        Group {
            switch layout {
            case .list:
                LoadableUI.List(store: store) { item in DemoRow(item: item) }
                    .empty { ContentUnavailableView("Nothing here yet", systemImage: "tray") }
                    .loading { ProgressView("Preparing the list…") }
                    .listStyle(.plain)
            case .cards, .grid:
                LoadableUI.Collection(store: store) { context in
                    ScrollView {
                        VStack(spacing: 16) {
                            LoadableUI.Components.Pagination(context: context.pagination(.previous))
                            if layout == .grid {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 16) {
                                    ForEach(context.items) { item in
                                        card(item).onAppear { context.itemAppeared(item) }
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(context.items) { item in
                                        card(item).onAppear { context.itemAppeared(item) }
                                    }
                                }
                            }
                            LoadableUI.Components.Pagination(context: context.pagination)
                        }
                        .padding(20)
                    }
                    .refreshable { await context.refresh() }
                    .overlay(alignment: .topTrailing) {
                        if context.presentation.isRefreshing { ProgressView().padding() }
                    }
                }
            }
        }
    }

    private func card(_ item: DemoItem) -> some View {
        DemoRow(item: item).padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.indigo.opacity(0.05), in: .rect(cornerRadius: 20))
    }
}

#Preview("UI · native list") { LoadableCollectionLayoutDemoView(layout: .list).demoPreviewSize(width: 440, height: 800) }
#Preview("UI · scrollable cards") { LoadableCollectionLayoutDemoView(layout: .cards).demoPreviewSize(width: 440, height: 800) }
#Preview("UI · adaptive grid") { LoadableCollectionLayoutDemoView(layout: .grid).demoPreviewSize(width: 800, height: 800) }
#Preview("UI · loaded cards") {
    LoadableCollectionLayoutDemoView(layout: .cards, snapshot: .loaded(layoutPeople))
        .demoPreviewSize(width: 440, height: 800)
}
#Preview("UI · loaded grid") {
    LoadableCollectionLayoutDemoView(layout: .grid, snapshot: .loaded(layoutPeople))
        .demoPreviewSize(width: 800, height: 800)
}
#Preview("UI · manual empty continuation") {
    ManualEmptyContinuationDemo().demoPreviewSize(width: 440, height: 600)
}

#Preview("UI · default idle") {
    LoadableUI.List(store: LoadableCollectionStore(
        source: LoadableCollectionBasicDemoView.DataSource(), constantSnapshot: .idle
    ), configuration: .init(startsAutomatically: false)) { DemoRow(item: $0) }
        .demoPreviewSize(width: 420, height: 500)
}
#Preview("UI · default empty") {
    LoadableUI.List(store: LoadableCollectionStore(items: [DemoItem]())) { DemoRow(item: $0) }
        .demoPreviewSize(width: 420, height: 500)
}
#Preview("UI · default failure") {
    LoadableUI.List(store: LoadableCollectionStore(
        source: LoadableCollectionBasicDemoView.DataSource(),
        constantSnapshot: .init(phase: .failed(DemoFailure.noConnection, operation: .reload))
    )) { DemoRow(item: $0) }.demoPreviewSize(width: 420, height: 500)
}
#Preview("UI · previous page loading") {
    LoadableUI.List(store: LoadableCollectionStore(
        source: LoadableCollectionBasicDemoView.DataSource(),
        constantSnapshot: .init(items: layoutPeople, phase: .loadingPage(.previous), hasLoaded: true)
    )) { DemoRow(item: $0) }.demoPreviewSize(width: 420, height: 650)
}

private let layoutPeople = (1...8).map {
    DemoItem(id: "person-\($0)", title: "Person \($0)", subtitle: "Layout example")
}

private struct ManualEmptyContinuationDemo: View {
    @State private var store = LoadableCollectionStore(
        source: LoadableCollection.OperationSource<DemoItem, Int, Never, any Error> { _, cursor, _ in
            if cursor == nil { return .init(items: [], nextCursor: 1) }
            return .init(items: [.init(id: "1", title: "Alice Smith", subtitle: "Loaded after an empty page")])
        }, configuration: .init(emptyPageFetchLimit: 0)
    )
    var body: some View {
        NavigationStack {
            LoadableUI.List(store: store, configuration: .init(pagination: .manual)) { DemoRow(item: $0) }
                .navigationTitle("Empty page with more data")
        }
    }
}
#endif
