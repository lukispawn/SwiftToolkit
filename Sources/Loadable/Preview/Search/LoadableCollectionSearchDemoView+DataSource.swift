#if DEBUG
import Foundation

extension LoadableCollectionSearchDemoView {
    actor DataSource: LoadableCollectionSource {
        typealias Item = DemoItem
        typealias Query = String
        typealias Cursor = Int

        private let allItems: [DemoItem]
        private let pageSize: Int
        private let delay: Duration

        init(itemCount: Int = 120, pageSize: Int = 15, delay: Duration = .milliseconds(1500)) {
            self.pageSize = max(1, pageSize)
            self.delay = delay
            allItems = Self.makeItems(count: max(0, itemCount))
        }

        func fetchPage(query: String?, cursor: Int?, direction: LoadableCollection.Direction) async throws -> Page {
            try Task.checkCancellation()
            try await Task.sleep(for: delay)
            let matching = Self.filter(allItems, query: query)
            let pageIndex = cursor ?? 0
            guard pageIndex >= 0, pageIndex <= matching.count / pageSize else {
                return .init(items: [], totalCount: matching.count)
            }
            let start = pageIndex * pageSize
            let end = min(start + pageSize, matching.count)
            guard start < end else { return .init(items: [], totalCount: matching.count) }
            return .init(items: Array(matching[start..<end]),
                         nextCursor: end < matching.count ? pageIndex + 1 : nil,
                         previousCursor: pageIndex > 0 ? pageIndex - 1 : nil,
                         totalCount: matching.count)
        }

        private static func filter(_ items: [DemoItem], query: String?) -> [DemoItem] {
            let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { return items }
            let locale = Locale(identifier: "en_US")
            let normalized = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            return items.filter {
                $0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale).contains(normalized)
            }
        }

        private static func makeItems(count: Int) -> [DemoItem] {
            // An accented surname keeps accent-insensitive search demonstrable.
            let surnames = ["Smith", "Johnson", "García", "Wilson", "Brown", "Davis", "Miller", "Taylor"]
            let names = ["Alice", "James", "Catherine", "Peter", "Mary", "Thomas"]
            return (0..<count).map { index in
                DemoItem(id: "person-\(index)",
                         title: "\(names[index % names.count]) \(surnames[(index / names.count) % surnames.count])",
                         subtitle: "Member ID \(1000000 + index)")
            }
        }
    }
}
#endif
