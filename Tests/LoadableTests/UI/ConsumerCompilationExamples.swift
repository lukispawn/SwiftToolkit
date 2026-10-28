// Compiler-checked consumer examples intentionally import only the public API.
import Loadable
import SwiftUI

@MainActor
private func customizedList(_ store: LoadableCollectionStore<ControlledCollectionSource>) -> some View {
    LoadableUI.List(store: store, configuration: .init(pagination: .manual, startsAutomatically: false)) {
        Text($0.id, format: .number)
    }
    .empty { Text("No items") }
    .loading { ProgressView("Please wait") }
    .failure { failure in
        VStack {
            Text(failure.error.localizedDescription)
            if let retry = failure.retry { Button("Try again", action: retry) }
        }
    }
    .idle { context in Button("Load", action: context.reload) }
    .pagination { context in
        switch context.state {
        case .available: Button("More", action: context.load)
        case .loading: ProgressView()
        case .failed: Button("Retry page", action: context.retry)
        case .hidden: EmptyView()
        }
    }
    .listStyle(.plain)
}

@MainActor
private func customizedContent(_ store: LoadableCollectionStore<ControlledCollectionSource>) -> some View {
    LoadableUI.Collection(store: store) { context in
        ScrollView {
            LazyVStack {
                LoadableUI.Components.Pagination(context: context.pagination(.previous), willLoad: {})
                ForEach(context.items) { row in
                    Text(row.id, format: .number).onAppear { context.itemAppeared(row) }
                }
                LoadableUI.Components.Pagination(context: context.pagination)
            }
        }
        .refreshable { await context.refresh() }
    }
    .empty { Text("No items") }
    .loading { ProgressView() }
    .failure { LoadableUI.Components.Failure(context: $0) }
    .idle { context in Button("Load", action: context.reload) }
}

@MainActor
private func defaultComponents(_ context: LoadableUI.CollectionContext<ControlledCollectionSource>) -> some View {
    VStack {
        LoadableUI.Components.Empty()
        LoadableUI.Components.Idle()
        LoadableUI.Components.Loading()
        LoadableUI.Components.Pagination(context: context.pagination)
        if let failure = context.failure {
            LoadableUI.Components.Failure(context: failure)
        }
    }
}

@MainActor
private func frozenFailureWithoutSource() -> some View {
    LoadableUI.List(store: LoadableCollectionStore(phase: .failed(TestFailure.offline))) { (row: Row) in
        Text(row.id, format: .number)
    }
}
