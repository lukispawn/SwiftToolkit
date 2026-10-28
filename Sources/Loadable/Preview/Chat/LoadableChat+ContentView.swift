#if DEBUG
import SwiftUI

extension LoadableChat {
    struct ContentView: View {
        @Bindable var viewModel: ViewModel
        @Binding var configuration: Configuration
        let startsWithKeyboard: Bool
        let restart: () -> Void
        @State private var messageFieldFrame = CGRect.zero
        @State private var sendTransition = SendTransition()
        @State private var automaticallyLoadsPages = true
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            chatSurface
                .overlayPreferenceValue(BubbleAnchorKey.self) { anchors in
                    GeometryReader { geometry in
                        if let flight = sendTransition.flight, let anchor = anchors[flight.message.id] {
                            SendFlightView(flight: flight, destination: geometry[anchor]) { id in
                                sendTransition.finish(id: id)
                            }
                            .id(flight.id)
                            .onAppear { sendTransition.markRunning(id: flight.id) }
                        }
                    }
                    .allowsHitTesting(false)
                }
                .coordinateSpace(.named(SendTransition.coordinateSpace))
                .tint(.indigo)
                .navigationTitle("Messages")
                .toolbar {
                    Button("Receive a message", systemImage: "bubble.left.and.bubble.right") {
                        viewModel.receiveGenerated()
                    }
                    .disabled(viewModel.isFrozen)
                    Button("Jump to latest", systemImage: "arrow.down.to.line", action: viewModel.jumpToLatest)
                        .disabled(viewModel.isFrozen)
                }
                .task(id: ObjectIdentifier(viewModel)) { viewModel.startIfNeeded() }
                .onDisappear { sendTransition.cancel(); viewModel.stop() }
                .onChange(of: reduceMotion) { if reduceMotion { sendTransition.cancel() } }
                .onChange(of: viewModel.history.snapshot.hasLoaded) {
                    if !viewModel.history.snapshot.hasLoaded { sendTransition.cancel() }
                }
                .onChange(of: ObjectIdentifier(viewModel)) { sendTransition.cancel() }
        }

        @ViewBuilder private var chatSurface: some View {
            if #available(iOS 26, macOS 26, *) {
                conversation.safeAreaBar(edge: .bottom, spacing: 0) { composer }
            } else {
                conversation.safeAreaInset(edge: .bottom, spacing: 0) { composer.background(.bar) }
            }
        }

        private var conversation: some View {
            VStack(spacing: 0) {
                header
                controls
                Divider()
                Transcript(viewModel: viewModel, flight: sendTransition.flight,
                           pagination: automaticallyLoadsPages ? .automatic : .manual)
            }
        }

        private var header: some View {
            HStack(spacing: 12) {
                Text("MC").font(.subheadline.weight(.semibold)).foregroundStyle(.indigo)
                    .frame(width: 42, height: 42).background(.indigo.opacity(0.1), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maya Chen").font(.headline)
                    Text("Local conversation · generated messages").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(viewModel.history.items.count) loaded")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }

        private var controls: some View {
            DisclosureGroup("Simulation controls") {
                VStack(spacing: 12) {
                    Picker("Scenario", selection: $configuration.scenario) {
                        ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Start at", selection: $configuration.window) {
                        ForEach(Window.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Response time", selection: $configuration.latency) {
                        ForEach(DemoLatency.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Follow new messages", isOn: $viewModel.followsNewMessages)
                    Toggle("Load pages automatically", isOn: $automaticallyLoadsPages)
                    HStack {
                        Button("Reset conversation", systemImage: "arrow.counterclockwise", action: restart)
                        Spacer()
                        Button("Generate text", systemImage: "text.badge.plus", action: viewModel.generateDraft)
                    }
                    .buttonStyle(.bordered)
                    Text("Reset starts a new local conversation. Older pages stay above; newer pages stay below. Sending keeps both cursors intact.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 12).disabled(viewModel.isFrozen)
            }
            .font(.caption).padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var composer: some View {
            VStack(spacing: 10) {
                if viewModel.outsideWindowCount > 0 {
                    Button("\(viewModel.outsideWindowCount) new messages outside this window · Jump to latest",
                           action: viewModel.jumpToLatest)
                        .font(.caption.weight(.medium))
                }
                if let error = viewModel.eventError { Text(error).font(.caption).foregroundStyle(.orange) }
                Composer(draft: $viewModel.draft, canSend: viewModel.canSend,
                         isSending: viewModel.outbox.contains { $0.delivery == .sending },
                         isEditable: !viewModel.isFrozen, focusesOnAppear: startsWithKeyboard,
                         onMessageFieldFrameChange: { messageFieldFrame = $0 }, send: sendMessage)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }

        private func sendMessage() {
            guard viewModel.canSend else { return }
            let sourceFrame = messageFieldFrame
            let followsLatest = viewModel.isAtLatestWindow && viewModel.followsNewMessages
            viewModel.sendDraft()
            if let message = viewModel.outbox.last {
                sendTransition.begin(message: message, sourceFrame: sourceFrame,
                                     reduceMotion: reduceMotion, followsLatest: followsLatest)
            }
        }
    }
}
#endif
