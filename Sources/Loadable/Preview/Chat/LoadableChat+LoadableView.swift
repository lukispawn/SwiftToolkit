#if DEBUG
import SwiftUI

extension LoadableChat {
    /// Demo host: owns the model and navigation; ContentView only presents it.
    struct LoadableView: View {
        @State private var viewModel: ViewModel
        @State private var configuration: Configuration
        private let startsWithKeyboard: Bool

        init(scenario: Scenario = .normal, window: Window = .middle,
             latency: DemoLatency = .normal, startsWithKeyboard: Bool = false,
             snapshot: Store.Snapshot? = nil) {
            self.startsWithKeyboard = startsWithKeyboard
            _configuration = State(initialValue: .init(scenario: scenario, window: window, latency: latency))
            if let snapshot {
                _viewModel = State(initialValue: ViewModel(source: Source(), window: window, frozen: snapshot))
            } else {
                _viewModel = State(initialValue: ViewModel(scenario: scenario, window: window, latency: latency))
            }
        }

        init(snapshot: Store.Snapshot, outbox: [Message]) {
            startsWithKeyboard = false
            _configuration = State(initialValue: .init(window: .latest))
            _viewModel = State(initialValue: ViewModel(previewSnapshot: snapshot, outbox: outbox))
        }

        var body: some View {
            NavigationStack {
                ContentView(viewModel: viewModel, configuration: $configuration,
                            startsWithKeyboard: startsWithKeyboard, restart: restart)
            }
            .onChange(of: configuration) { restart() }
        }

        private func restart() {
            guard !viewModel.isFrozen else { return }
            viewModel.stop()
            viewModel = ViewModel(scenario: configuration.scenario, window: configuration.window,
                                  latency: configuration.latency)
        }
    }
}
#endif
