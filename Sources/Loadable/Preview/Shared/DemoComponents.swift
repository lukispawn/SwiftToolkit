#if DEBUG
import SwiftUI

struct DemoRow: View {
    let item: DemoItem

    var body: some View {
        HStack(spacing: 14) {
            Text(item.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(.indigo.opacity(0.08), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.body.weight(.medium))
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct DemoMessage: View {
    let title: String
    let systemImage: String
    var detail: String = ""
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(detail)
        } actions: {
            if let action {
                Button(actionTitle ?? "Retry", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct DemoErrorBanner: View {
    let title: String
    let detail: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(detail).font(.caption).foregroundStyle(.secondary)
            Button("Retry request", action: retry).buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.06), in: .rect(cornerRadius: 16))
    }
}

struct DemoIntroduction: View {
    let category: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.uppercased())
                .font(.caption.weight(.semibold)).tracking(1.2)
                .foregroundStyle(.indigo)
            Text(title).font(.title2.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DemoStatusBar: View {
    let phase: String
    var isLoading = false
    var hasError = false
    var itemCount: Int?
    var canLoadMore = false
    var query: String?
    var pendingQuery: String?
    var debouncePending: Bool?
    var cursor: String?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: hasError ? "exclamationmark.circle.fill" : "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(hasError ? Color.orange : isLoading ? .indigo : .green)
                    .accessibilityHidden(true)
                Text(phase).font(.caption.weight(.semibold))
                Spacer()
                if let itemCount {
                    Text("Results: \(itemCount)").font(.caption).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("Diagnostics", isExpanded: $isExpanded) {
                VStack(spacing: 8) {
                    if itemCount != nil {
                        LabeledContent("Next page", value: canLoadMore ? "Available" : "None")
                    }
                    if let cursor { LabeledContent("Cursor", value: cursor) }
                    if query != nil || debouncePending != nil {
                        LabeledContent("Active query", value: label(query))
                    }
                    if let debouncePending {
                        LabeledContent("Debounce", value: debouncePending ? "Pending" : "Ready")
                        LabeledContent("Pending query", value: label(pendingQuery))
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            .font(.caption)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func label(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
    }
}

#Preview("Row · person") {
    DemoRow(item: .init(id: "1", title: "Alice Smith", subtitle: "Member ID 1000001"))
        .padding(20).demoPreviewSize(width: 420)
}
#Preview("Message · no results") {
    DemoMessage(title: "No results", systemImage: "tray", detail: "Try a different search.")
        .demoPreviewSize(width: 420, height: 320)
}
#Preview("Warning · retry") {
    DemoErrorBanner(title: "Your results remain visible", detail: DemoFailure.timeout.localizedDescription, retry: {})
        .padding(20).demoPreviewSize(width: 420)
}
#Preview("Introduction") {
    DemoIntroduction(category: "Collection Store", title: "Page by page", detail: "Refresh and retry with confidence.")
        .padding(20).demoPreviewSize(width: 420)
}
#Preview("Diagnostics · search") {
    DemoStatusBar(phase: "Refreshing", isLoading: true, itemCount: 15, canLoadMore: true,
                  query: "Smith", pendingQuery: "Smithson", debouncePending: true, cursor: "1")
        .demoPreviewSize(width: 420)
}
#endif
