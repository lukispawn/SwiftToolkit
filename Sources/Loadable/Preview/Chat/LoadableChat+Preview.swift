#if DEBUG
import SwiftUI

private extension LoadableChat {
    static let previewMessages = (40...47).map { Message.generated($0) }
}

#Preview("Chat · bidirectional history") {
    LoadableChat.LoadableView().demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · latest messages and sending") {
    LoadableChat.LoadableView(window: .latest).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · page failures and retry") {
    LoadableChat.LoadableView(scenario: .pageFailures).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · failed send and retry") {
    LoadableChat.LoadableView(scenario: .sendFailure, window: .latest).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · loaded conversation") {
    LoadableChat.LoadableView(snapshot: .loaded(LoadableChat.previewMessages, nextCursor: .after(47), previousCursor: .before(40)))
        .demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · loading older messages") {
    LoadableChat.LoadableView(snapshot: .init(items: LoadableChat.previewMessages, phase: .loadingPage(.previous), hasLoaded: true))
        .demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · retained page error") {
    LoadableChat.LoadableView(snapshot: .init(items: LoadableChat.previewMessages,
        phase: .failed(LoadableChat.Failure.newer, operation: .page(.next)), hasLoaded: true))
        .demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · empty conversation") {
    LoadableChat.LoadableView(snapshot: .loaded([])).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · start an empty conversation") {
    LoadableChat.LoadableView(scenario: .emptyConversation, window: .latest).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · pending message before remote save") {
    LoadableChat.LoadableView(snapshot: .loaded((85...90).map { LoadableChat.Message.generated($0) }), outbox: [
        LoadableChat.Message(id: "local-pending-preview", sequence: 91,
                        text: "This message is visible locally while the server is still saving it.",
                        sender: .me, sentAt: LoadableChat.Message.baseDate.addingTimeInterval(91 * 180),
                        delivery: .sending)
    ])
    .demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · slow sending (3 seconds)") {
    LoadableChat.LoadableView(window: .latest, latency: .verySlow).demoPreviewSize(width: 460, height: 900)
}
#Preview("Chat · animated send with keyboard") {
    LoadableChat.LoadableView(window: .latest, latency: .slow, startsWithKeyboard: true)
        .demoPreviewSize(width: 460, height: 900)
}
#endif
