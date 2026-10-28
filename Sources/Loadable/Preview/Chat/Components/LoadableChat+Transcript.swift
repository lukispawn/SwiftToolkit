#if DEBUG
import SwiftUI

extension LoadableChat {
    struct Transcript: View {
        let viewModel: ViewModel
        let flight: SendTransition.Flight?
        let pagination: LoadableUI.Configuration.Pagination

        var body: some View {
            LoadableUI.Collection(store: viewModel.history, configuration: .init(
                pagination: pagination, isRefreshable: false, startsAutomatically: false
            )) { context in
                ScrollContent(viewModel: viewModel, context: context, flight: flight)
            }
            .empty {
                if viewModel.timeline.isEmpty {
                    DemoMessage(title: "Start the conversation", systemImage: "bubble.left.and.bubble.right",
                                detail: "Write a message below or generate some text.")
                } else {
                    ScrollContent(viewModel: viewModel, context: .init(store: viewModel.history, configuration: .init(
                        pagination: pagination, isRefreshable: false, startsAutomatically: false
                    )), flight: flight)
                }
            }
            .loading { ProgressView("Opening the conversation…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            .failure { failure in
                DemoMessage(title: "Could not open the conversation", systemImage: "wifi.slash",
                            detail: failure.error.localizedDescription, action: failure.retry)
            }
            .idle { context in
                DemoMessage(title: "Conversation paused", systemImage: "pause.circle",
                            detail: "Resume to load message history.", actionTitle: "Resume", action: context.reload)
            }
        }
    }
}
#endif
