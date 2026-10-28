#if DEBUG
import SwiftUI

/// One Observable ViewModel combines two value stores and a collection store.
struct LoadableStateDemoView: View {
    @State private var model: Model
    @State private var scenario: Scenario

    init(scenario: Scenario = .success, frozen: Model.FrozenState? = nil) {
        _scenario = State(initialValue: scenario)
        _model = State(initialValue: Model(scenario: scenario, frozen: frozen))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DemoIntroduction(category: "Shared state", title: "Three stores. One screen.",
                        detail: "Content appears when profile, permissions and people are ready. Refresh and page errors keep it visible.")
                    Picker("Scenario", selection: $scenario) {
                        ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .disabled(model.isFrozen)
                    status
                    content
                }
                .padding(20)
            }
            .navigationTitle("Merged state")
            .toolbar {
                Button("Refresh all", systemImage: "arrow.clockwise", action: model.refreshAll)
                    .disabled(model.isFrozen)
                Button("Reload all", systemImage: "arrow.down.circle", action: model.reloadAll)
                    .disabled(model.isFrozen)
                Button("Cancel", systemImage: "pause", action: model.cancelAll)
                    .disabled(model.isFrozen)
            }
        }
        .tint(.indigo)
        .task { model.startIfNeeded() }
        .onDisappear { model.cancelAll() }
        .onChange(of: scenario) {
            model.cancelAll()
            model = Model(scenario: scenario)
            model.startIfNeeded()
        }
    }

    private var status: some View {
        let state = model.loadableState
        return VStack(spacing: 10) {
            LabeledContent("Screen", value: title(state.phase)).font(.headline)
            LabeledContent("Ready stores", value: "\(state.loadedStoreCount) / \(state.storeCount)")
            Divider()
            LabeledContent("Profile", value: title(model.profile.loadableState.phase))
            LabeledContent("Permissions", value: title(model.permissions.loadableState.phase))
            LabeledContent("People", value: title(model.people.loadableState.phase))
            if state.isRefreshing { ProgressView("Refreshing existing data…") }
            if state.isLoadingPage { ProgressView("Loading the next page…") }
        }
        .font(.subheadline)
        .padding(16)
        .background(.secondary.opacity(0.05), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder private var content: some View {
        let state = model.loadableState
        switch state.phase {
        case .idle:
            DemoMessage(title: "Waiting for required data", systemImage: "pause.circle",
                        detail: "Some requests have not started or were cancelled.",
                        actionTitle: "Reload all", action: reloadAction)
        case .loading:
            ProgressView("Waiting for every required store…")
                .frame(maxWidth: .infinity).padding(.vertical, 40)
        case .failed:
            DemoMessage(title: "Required data is unavailable", systemImage: "wifi.slash",
                        detail: state.blockingFailures.first?.error.localizedDescription ?? "",
                        action: retryAction)
        case .loaded: loadedContent
        }
    }

    private var loadedContent: some View {
        let state = model.loadableState
        return VStack(alignment: .leading, spacing: 16) {
            if !state.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Content remains available", systemImage: "exclamationmark.circle")
                        .font(.headline).foregroundStyle(.orange)
                    ForEach(Array(state.errors.enumerated()), id: \.offset) { _, error in
                        Text(error.localizedDescription).font(.caption)
                    }
                    if !model.isFrozen {
                        Button("Retry failed requests", action: model.retryFailed).buttonStyle(.bordered)
                    }
                }
            }
            if let profile = model.profile.value { DemoProfileCard(profile: profile) }
            if let permissions = model.permissions.value {
                Label(permissions, systemImage: "checkmark.shield")
            }
            ForEach(model.people.items) { DemoRow(item: $0) }
            LoadableUI.Components.Pagination(context: LoadableUI.CollectionContext(store: model.people).pagination)
        }
    }

    private var reloadAction: (() -> Void)? {
        guard !model.isFrozen else { return nil }
        return { model.reloadAll() }
    }

    private var retryAction: (() -> Void)? {
        guard !model.isFrozen else { return nil }
        return { model.retryFailed() }
    }

    private func title(_ phase: LoadableState.Phase) -> String {
        switch phase {
        case .idle: "Idle"
        case .loading: "Loading"
        case .loaded: "Loaded"
        case .failed: "Failed"
        }
    }
}

#Preview("State · live multi-store screen") {
    LoadableStateDemoView().demoPreviewSize(width: 480, height: 900)
}
#Preview("State · all required stores loaded") {
    LoadableStateDemoView(frozen: .loaded).demoPreviewSize(width: 480, height: 900)
}
#Preview("State · one required store loading") {
    LoadableStateDemoView(frozen: .loading).demoPreviewSize(width: 480, height: 800)
}
#Preview("State · blocking first-load failure") {
    LoadableStateDemoView(frozen: .failed).demoPreviewSize(width: 480, height: 800)
}
#Preview("State · retained refresh failure") {
    LoadableStateDemoView(frozen: .refreshFailed).demoPreviewSize(width: 480, height: 1000)
}
#Preview("State · retained page failure") {
    LoadableStateDemoView(frozen: .pageFailed).demoPreviewSize(width: 480, height: 1000)
}
#endif
