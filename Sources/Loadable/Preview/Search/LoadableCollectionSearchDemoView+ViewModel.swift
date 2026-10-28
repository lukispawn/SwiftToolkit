#if DEBUG
extension LoadableCollectionSearchDemoView {
    typealias ViewModel = LoadableCollectionSearch<DataSource>
}

extension LoadableCollectionSearch where Source == LoadableCollectionSearchDemoView.DataSource {
    convenience init(minimumLength: Int, debounce: Duration, showsAllWhenEmpty: Bool,
                     responseDelay: Duration) {
        self.init(store: .init(source: Source(delay: responseDelay)), minimumLength: minimumLength,
                  debounce: debounce, showsAllWhenEmpty: showsAllWhenEmpty)
    }
}
#endif
