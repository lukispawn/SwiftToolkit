#if DEBUG
import SwiftUI

extension LoadableChat {
    struct Bubble: View {
        let message: Message
        let retry: (() -> Void)?
        var flyingMessageID: String?

        var body: some View {
            HStack(alignment: .bottom, spacing: 8) {
                if message.sender == .me { Spacer(minLength: 44) }
                VStack(alignment: .leading, spacing: 7) {
                    Text(message.text).font(.body).textSelection(.enabled)
                    HStack(spacing: 6) {
                        Text(message.sentAt, format: .dateTime.hour().minute())
                        if message.sender == .me {
                            switch message.delivery {
                            case .sending: Label("Sending…", systemImage: "clock")
                            case .sent: Label("Sent", systemImage: "checkmark")
                            case .failed: Label("Not sent", systemImage: "exclamationmark.circle.fill")
                            }
                        }
                    }
                    .font(.caption2).opacity(0.75)
                    if case .failed(let reason) = message.delivery {
                        Text(reason).font(.caption)
                        if let retry {
                            Button("Retry sending", action: retry).font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .foregroundStyle(message.sender == .me ? Color.white : .primary)
                .tint(message.sender == .me ? .white : .indigo)
                .background(message.sender == .me ? Color.indigo : .secondary.opacity(0.10),
                            in: .rect(cornerRadius: 18))
                .anchorPreference(key: BubbleAnchorKey.self, value: .bounds) { anchor in
                    message.id == flyingMessageID ? [message.id: anchor] : [:]
                }
                if message.sender == .maya { Spacer(minLength: 44) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(message.sender == .me ? "Your message" : "Message from Maya")
        }
    }
}
#endif
