#if DEBUG
import SwiftUI

public struct LoadableValueDemoView: View {
    @State private var store: LoadableValueStore<DataSource>
    @State private var behavior: DataSource.Behavior
    @State private var latency = DemoLatency.normal

    public init() { self.init(behavior: .success) }

    init(behavior: DataSource.Behavior) {
        _behavior = State(initialValue: behavior)
        _store = State(initialValue: .init(source: DataSource(behavior: behavior)))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DemoIntroduction(category: "Value Store", title: "One profile. Every state.",
                                     detail: "Compare refreshing while keeping data with reloading from an empty state.")
                    controls
                    content
                    actions
                }
                .padding(20)
            }
            .navigationTitle("Single value")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                DemoStatusBar(phase: store.snapshot.phase.demoDescription,
                              isLoading: store.snapshot.phase.isLoading, hasError: store.lastError != nil)
            }
            .toolbar {
                Button("Cancel", systemImage: "pause") { store.cancelRequest() }
            }
        }
        .tint(.indigo)
        .task { store.startIfNeeded() }
        .onDisappear { store.cancel() }
        .onChange(of: behavior) { restart() }
        .onChange(of: latency) { restart() }
    }

    private var controls: some View {
        DisclosureGroup("Scenario and response time") {
            VStack(spacing: 12) {
                Picker("Scenario", selection: $behavior) {
                    ForEach(DataSource.Behavior.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Response time", selection: $latency) {
                    ForEach(DemoLatency.allCases) { Text($0.rawValue).tag($0) }
                }
                Button("Reset scenario", systemImage: "arrow.counterclockwise", action: restart)
                    .buttonStyle(.bordered)
            }
            .padding(.top, 12)
        }
        .font(.subheadline)
    }

    @ViewBuilder private var content: some View {
        if let profile = store.value {
            DemoProfileCard(profile: profile)
            if let error = store.lastError {
                DemoErrorBanner(title: "Previous data remains visible", detail: error.localizedDescription) {
                    store.retry()
                }
            }
        } else if store.snapshot.phase.isLoading {
            DemoProfileCard(profile: DemoProfile(revision: 0)).redacted(reason: .placeholder)
                .overlay { ProgressView("Loading profile…").padding(16).background(.regularMaterial, in: .capsule) }
                .accessibilityLabel("Loading profile")
        } else if let error = store.lastError {
            DemoMessage(title: "Could not load the profile", systemImage: "wifi.slash",
                        detail: error.localizedDescription, action: { store.retry() })
        } else {
            DemoMessage(title: "Profile ready to load", systemImage: "person.crop.circle",
                        detail: "Choose Reload from scratch to begin.")
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { store.refreshInBackground() } label: {
                Label("Refresh and keep data", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { store.reload() } label: {
                Label("Reload from scratch", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            if store.snapshot.phase.isLoading, store.value != nil {
                ProgressView("Refreshing profile…").font(.caption).padding(.top, 4)
            }
        }
        .controlSize(.large)
    }

    private func restart() {
        store.cancel()
        store = .init(source: DataSource(behavior: behavior, delay: latency.duration))
        store.start()
    }
}

struct DemoProfileCard: View {
    let profile: DemoProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle).foregroundStyle(.indigo)
                    .padding(12).background(.indigo.opacity(0.08), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.title3.weight(.semibold))
                    Text(profile.role).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            VStack(spacing: 12) {
                LabeledContent("City", value: profile.city)
                LabeledContent("Data version", value: "\(profile.revision)").monospacedDigit()
            }
            .font(.subheadline)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: .rect(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.quaternary, lineWidth: 1) }
    }
}

#Preview("Value · loading and refreshing") { LoadableValueDemoView().demoPreviewSize(width: 420, height: 780) }
#Preview("Value · failure and retry") {
    LoadableValueDemoView(behavior: .failsFirst).demoPreviewSize(width: 420, height: 780)
}
#Preview("Value · refresh failure") {
    LoadableValueDemoView(behavior: .failsRefresh).demoPreviewSize(width: 420, height: 780)
}
#endif
