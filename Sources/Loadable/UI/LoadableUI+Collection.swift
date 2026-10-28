import SwiftUI

extension LoadableUI {
    /// Renders loading/idle/empty/failure states and delegates the loaded layout to content.
    /// Injected stores are observed directly; this view never cancels a shared store on disappearance.
    public struct Collection<Source: LoadableCollectionSource, Content: View,
        Empty: View, Loading: View, FailureContent: View, Idle: View>: View {
        let store: LoadableCollectionStore<Source>
        let configuration: LoadableUI.Configuration
        let content: (LoadableUI.CollectionContext<Source>) -> Content
        let emptyContent: () -> Empty
        let loadingContent: () -> Loading
        let failureContent: (LoadableUI.FailureContext<Source.Failure>) -> FailureContent
        let idleContent: (LoadableUI.CollectionContext<Source>) -> Idle

        public init(store: LoadableCollectionStore<Source>, configuration: LoadableUI.Configuration = .init(),
                    @ViewBuilder content: @escaping (LoadableUI.CollectionContext<Source>) -> Content,
                    @ViewBuilder empty: @escaping () -> Empty,
                    @ViewBuilder loading: @escaping () -> Loading,
                    @ViewBuilder failure: @escaping (LoadableUI.FailureContext<Source.Failure>) -> FailureContent,
                    @ViewBuilder idle: @escaping (LoadableUI.CollectionContext<Source>) -> Idle) {
            self.store = store
            self.configuration = configuration
            self.content = content
            emptyContent = empty
            loadingContent = loading
            failureContent = failure
            idleContent = idle
        }

        public var body: some View {
            let context = LoadableUI.CollectionContext(store: store, configuration: configuration)
            surface(context)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    guard !Task.isCancelled else { return }
                    context.startIfNeeded()
                }
        }

        @ViewBuilder private func surface(_ context: LoadableUI.CollectionContext<Source>) -> some View {
            switch context.presentation.state {
            case .idle: idleContent(context)
            case .loading: loadingContent()
            case .empty: emptyContent()
            case .failed:
                if let failure = context.failure { failureContent(failure) }
            case .content:
                VStack(spacing: 0) {
                    // This branch stays content during refresh, preserving the container's identity.
                    if let failure = context.refreshFailure { failureContent(failure) }
                    content(context)
                }
            }
        }
    }
}

public extension LoadableUI.Collection where Empty == LoadableUI.Components.Empty,
    Loading == LoadableUI.Components.Loading, FailureContent == LoadableUI.Components.Failure<Source.Failure>,
    Idle == LoadableUI.Components.Idle {
    init(store: LoadableCollectionStore<Source>, configuration: LoadableUI.Configuration = .init(),
         @ViewBuilder content: @escaping (LoadableUI.CollectionContext<Source>) -> Content) {
        self.init(store: store, configuration: configuration, content: content,
                  empty: { LoadableUI.Components.Empty() }, loading: { LoadableUI.Components.Loading() },
                  failure: { LoadableUI.Components.Failure(context: $0) }, idle: { _ in LoadableUI.Components.Idle() })
    }
}

public extension LoadableUI.Collection {
    func empty<Replacement: View>(@ViewBuilder _ replacement: @escaping () -> Replacement)
    -> LoadableUI.Collection<Source, Content, Replacement, Loading, FailureContent, Idle> {
        .init(store: store, configuration: configuration, content: content,
              empty: replacement, loading: loadingContent,
              failure: failureContent, idle: idleContent)
    }

    func loading<Replacement: View>(@ViewBuilder _ replacement: @escaping () -> Replacement)
    -> LoadableUI.Collection<Source, Content, Empty, Replacement, FailureContent, Idle> {
        .init(store: store, configuration: configuration, content: content,
              empty: emptyContent, loading: replacement,
              failure: failureContent, idle: idleContent)
    }

    func failure<Replacement: View>(@ViewBuilder _ replacement: @escaping (LoadableUI.FailureContext<Source.Failure>) -> Replacement)
    -> LoadableUI.Collection<Source, Content, Empty, Loading, Replacement, Idle> {
        .init(store: store, configuration: configuration, content: content,
              empty: emptyContent, loading: loadingContent,
              failure: replacement, idle: idleContent)
    }

    func idle<Replacement: View>(@ViewBuilder _ replacement: @escaping (LoadableUI.CollectionContext<Source>) -> Replacement)
    -> LoadableUI.Collection<Source, Content, Empty, Loading, FailureContent, Replacement> {
        .init(store: store, configuration: configuration, content: content,
              empty: emptyContent, loading: loadingContent,
              failure: failureContent, idle: replacement)
    }

}
