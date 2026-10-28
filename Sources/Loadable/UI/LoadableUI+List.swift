import SwiftUI

extension LoadableUI {
    /// A ready-to-use List. Row selection, navigation and actions remain native row composition.
    public struct List<Source: LoadableCollectionSource, Row: View, Empty: View,
        Loading: View, FailureContent: View, Idle: View, Pagination: View>: View {
        let store: LoadableCollectionStore<Source>
        let configuration: LoadableUI.Configuration
        let row: (Source.Item) -> Row
        let emptyContent: () -> Empty
        let loadingContent: () -> Loading
        let failureContent: (LoadableUI.FailureContext<Source.Failure>) -> FailureContent
        let idleContent: (LoadableUI.CollectionContext<Source>) -> Idle
        let paginationContent: (LoadableUI.PaginationContext<Source>) -> Pagination

        init(store: LoadableCollectionStore<Source>, configuration: LoadableUI.Configuration,
             row: @escaping (Source.Item) -> Row, empty: @escaping () -> Empty,
             loading: @escaping () -> Loading,
             failure: @escaping (LoadableUI.FailureContext<Source.Failure>) -> FailureContent,
             idle: @escaping (LoadableUI.CollectionContext<Source>) -> Idle,
             pagination: @escaping (LoadableUI.PaginationContext<Source>) -> Pagination) {
            self.store = store
            self.configuration = configuration
            self.row = row
            emptyContent = empty
            loadingContent = loading
            failureContent = failure
            idleContent = idle
            paginationContent = pagination
        }

        public var body: some View {
            LoadableUI.Collection(store: store, configuration: configuration) { context in
                list(context)
            } empty: { emptyContent() } loading: { loadingContent() }
              failure: { failureContent($0) } idle: { idleContent($0) }
        }

        @ViewBuilder private func list(_ context: LoadableUI.CollectionContext<Source>) -> some View {
            // Refresh support is a structural policy. Keep configuration stable to retain scroll state.
            if context.canRefresh {
                rows(context).refreshable { await context.refresh() }
            } else {
                rows(context)
            }
        }

        private func rows(_ context: LoadableUI.CollectionContext<Source>) -> some View {
            SwiftUI.List {
                paginationContent(context.pagination(.previous))
                    .listRowSeparator(.hidden)
                ForEach(context.items) { item in
                    row(item).onAppear { context.itemAppeared(item) }
                }
                paginationContent(context.pagination)
                    .listRowSeparator(.hidden)
            }
            .overlay(alignment: .topTrailing) {
                if context.presentation.isRefreshing {
                    ProgressView("Refreshing…").padding(12)
                        .background(.regularMaterial, in: .capsule).padding(12)
                }
            }
        }
    }
}

public extension LoadableUI.List where Empty == LoadableUI.Components.Empty, Loading == LoadableUI.Components.Loading,
    FailureContent == LoadableUI.Components.Failure<Source.Failure>, Idle == LoadableUI.Components.Idle,
    Pagination == LoadableUI.Components.Pagination<Source> {
    init(store: LoadableCollectionStore<Source>, configuration: LoadableUI.Configuration = .init(),
         @ViewBuilder row: @escaping (Source.Item) -> Row) {
        self.init(store: store, configuration: configuration, row: row,
                  empty: { LoadableUI.Components.Empty() }, loading: { LoadableUI.Components.Loading() },
                  failure: { LoadableUI.Components.Failure(context: $0) }, idle: { _ in LoadableUI.Components.Idle() },
                  pagination: { LoadableUI.Components.Pagination(context: $0) })
    }
}

public extension LoadableUI.List {
    func empty<Replacement: View>(@ViewBuilder _ replacement: @escaping () -> Replacement)
    -> LoadableUI.List<Source, Row, Replacement, Loading, FailureContent, Idle, Pagination> {
        .init(store: store, configuration: configuration, row: row,
              empty: replacement, loading: loadingContent, failure: failureContent,
              idle: idleContent, pagination: paginationContent)
    }

    func loading<Replacement: View>(@ViewBuilder _ replacement: @escaping () -> Replacement)
    -> LoadableUI.List<Source, Row, Empty, Replacement, FailureContent, Idle, Pagination> {
        .init(store: store, configuration: configuration, row: row,
              empty: emptyContent, loading: replacement, failure: failureContent,
              idle: idleContent, pagination: paginationContent)
    }

    func failure<Replacement: View>(@ViewBuilder _ replacement: @escaping (LoadableUI.FailureContext<Source.Failure>) -> Replacement)
    -> LoadableUI.List<Source, Row, Empty, Loading, Replacement, Idle, Pagination> {
        .init(store: store, configuration: configuration, row: row,
              empty: emptyContent, loading: loadingContent, failure: replacement,
              idle: idleContent, pagination: paginationContent)
    }

    func idle<Replacement: View>(@ViewBuilder _ replacement: @escaping (LoadableUI.CollectionContext<Source>) -> Replacement)
    -> LoadableUI.List<Source, Row, Empty, Loading, FailureContent, Replacement, Pagination> {
        .init(store: store, configuration: configuration, row: row,
              empty: emptyContent, loading: loadingContent, failure: failureContent,
              idle: replacement, pagination: paginationContent)
    }

    func pagination<Replacement: View>(@ViewBuilder _ replacement: @escaping (LoadableUI.PaginationContext<Source>) -> Replacement)
    -> LoadableUI.List<Source, Row, Empty, Loading, FailureContent, Idle, Replacement> {
        .init(store: store, configuration: configuration, row: row,
              empty: emptyContent, loading: loadingContent, failure: failureContent,
              idle: idleContent, pagination: replacement)
    }

}
