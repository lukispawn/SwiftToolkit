#if DEBUG
import Foundation

extension LoadableCollectionBasicDemoView {
    actor DataSource: LoadableCollectionSource {
        typealias Item = DemoItem
        typealias Cursor = Int
        typealias Query = Never

        enum Behavior: String, CaseIterable, Identifiable, Sendable {
            case success = "Full list"
            case empty = "Empty results"
            case failsOnFirstPage = "First-page failure · once"
            case failsOnNextPage = "Next-page failure · once"
            case emptyIntermediate = "Empty intermediate page"
            case bidirectional = "Bidirectional pagination"
            var id: String { rawValue }
        }

        private let behavior: Behavior
        private let delay: Duration
        private let pageCount: Int
        private let itemsPerPage: Int
        private var failedPages: Set<Int> = []

        init(behavior: Behavior = .success, delay: Duration = .milliseconds(600),
             pageCount: Int = 5, itemsPerPage: Int = 15) {
            self.behavior = behavior
            self.delay = delay
            self.pageCount = max(1, pageCount)
            self.itemsPerPage = max(1, itemsPerPage)
        }

        func fetchPage(query: Never?, cursor: Int?, direction: LoadableCollection.Direction) async throws -> Page {
            try Task.checkCancellation()
            try await Task.sleep(for: delay)
            let index = cursor ?? (behavior == .bidirectional ? min(2, pageCount - 1) : 0)
            guard behavior != .empty, index >= 0, index < pageCount else { return .init(items: []) }

            let shouldFail = behavior == .failsOnFirstPage && index == 0 || behavior == .failsOnNextPage && index == 1
            if shouldFail, failedPages.insert(index).inserted {
                throw index == 0 ? DemoFailure.noConnection : DemoFailure.timeout
            }

            let isEmptyPage = behavior == .emptyIntermediate && index == 1
            let items: [DemoItem] = isEmptyPage ? [] : (0..<itemsPerPage).map { position in
                let number = index * itemsPerPage + position + 1
                return DemoItem(id: "item-\(number)", title: "Item \(number)",
                                subtitle: "Page \(index + 1) of \(pageCount)")
            }
            return Page(items: items, nextCursor: index + 1 < pageCount ? index + 1 : nil,
                        previousCursor: index > 0 ? index - 1 : nil,
                        totalCount: (pageCount - (behavior == .emptyIntermediate ? 1 : 0)) * itemsPerPage)
        }
    }
}
#endif
