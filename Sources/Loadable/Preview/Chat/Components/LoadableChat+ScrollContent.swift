#if DEBUG
import SwiftUI

extension LoadableChat {
    struct ScrollContent: View {
        let viewModel: ViewModel
        let context: LoadableUI.CollectionContext<Source>
        let flight: SendTransition.Flight?
        @State private var visibleMessageID: String?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        LoadableUI.Components.Pagination(context: context.pagination(.previous)) {
                            viewModel.followsNewMessages = false
                        }
                        ForEach(viewModel.timeline) { message in
                            Bubble(message: message, retry: viewModel.retryAction(for: message.id),
                                   flyingMessageID: flight?.message.id)
                                .opacity(flight?.isRunning == true && flight?.message.id == message.id ? 0 : 1)
                                .id(message.id)
                        }
                        LoadableUI.Components.Pagination(context: context.pagination)
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollPosition(id: $visibleMessageID, anchor: .top)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.timeline.last?.id) {
                    guard viewModel.followsNewMessages, viewModel.isAtLatestWindow, let id = viewModel.timeline.last?.id else { return }
                    if reduceMotion || flight?.message.id == id { proxy.scrollTo(id, anchor: .bottom) }
                    else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
        }
    }
}
#endif
