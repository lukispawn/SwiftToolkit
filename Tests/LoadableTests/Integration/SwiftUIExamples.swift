// Compiler-checked integration examples. Runtime rendering is verified by the host app.
import Loadable
import SwiftUI

@MainActor
private struct ValueExample: View {
    @State private var store = LoadableValueStore(operation: { 42 })

    var body: some View {
        VStack {
            if let value = store.value { Text(value, format: .number) }
            if store.snapshot.phase.isLoading { ProgressView() }
            if store.lastError != nil { Button("Retry") { store.retry() } }
        }
        .task { _ = try? await store.load() }
        .refreshable { await store.refresh() }
    }
}

@MainActor
private struct CollectionExample: View {
    @State private var store = LoadableCollectionStore(operation: { [Row(1), Row(2)] })

    var body: some View {
        List {
            ForEach(store.items) { item in
                Text(item.id, format: .number)
                    .onAppear { store.loadMoreIfNeeded(for: item) }
            }
            if store.snapshot.phase.isLoading { ProgressView() }
            if store.lastError != nil { Button("Retry") { store.retry() } }
        }
        .task { store.startIfNeeded() }
        .refreshable { await store.refresh() }
    }
}

@MainActor
private struct SearchExample: View {
    private typealias Source = LoadableCollection.OperationSource<Row, Never, String, Never>
    @State private var query = ""
    @State private var store: LoadableCollectionStore<Source>
    @State private var debouncer: LoadableQueryDebouncer<String>

    init() {
        let store = LoadableCollectionStore(source: Source { query, _, _ in
            .init(items: query?.isEmpty == false ? [Row(1)] : [])
        })
        _store = State(initialValue: store)
        _debouncer = State(initialValue: LoadableQueryDebouncer { [weak store] query, mode in
            store?.start(query: query, force: mode == .immediate)
        })
    }

    var body: some View {
        List(store.items) { item in Text(item.id, format: .number) }
            .searchable(text: $query)
            .onChange(of: query) { debouncer.submit(query) }
            .onSubmit(of: .search) { debouncer.submitNow(query) }
            .task { store.start(query: query) }
            .onDisappear { debouncer.cancelPending() }
    }
}
