#if DEBUG
import SwiftUI

extension LoadableChat {
    struct Composer: View {
        @Binding var draft: String
        let canSend: Bool
        let isSending: Bool
        let isEditable: Bool
        var focusesOnAppear = false
        var onMessageFieldFrameChange: (CGRect) -> Void = { _ in }
        let send: () -> Void
        @FocusState private var isFocused: Bool

        private var showsSending: Bool {
            isSending && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var body: some View {
            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    HStack(alignment: .bottom, spacing: 10) {
                        messageField.glassEffect(.regular, in: .rect(cornerRadius: 26))
                        if showsSending {
                            sendingIndicator.glassEffect(.regular.tint(.blue), in: .circle)
                        } else {
                            sendButton.buttonStyle(.glassProminent)
                        }
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    messageField.background(.regularMaterial, in: .rect(cornerRadius: 26))
                    if showsSending {
                        sendingIndicator.background(.blue, in: .circle)
                    } else {
                        sendButton.buttonStyle(.borderedProminent)
                    }
                }
            }
        }

        private var messageField: some View {
            TextField("Message Maya…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .disabled(!isEditable)
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .named(SendTransition.coordinateSpace))
                } action: { frame in
                    onMessageFieldFrameChange(frame)
                }
                .onAppear {
                    if focusesOnAppear && isEditable { isFocused = true }
                }
        }

        private var sendButton: some View {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(.blue)
            .accessibilityLabel("Send message")
            .disabled(!canSend)
        }

        private var sendingIndicator: some View {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
                .frame(width: 52, height: 52)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sending messages")
                .accessibilityValue("Waiting for the server")
        }
    }
}

#Preview("Chat composer · ready to send") {
    LoadableChat.Composer(draft: .constant("Let's try the new conversation preview."), canSend: true,
                     isSending: false, isEditable: true, send: {})
        .padding(16)
        .demoPreviewSize(width: 440, height: 160)
}

#Preview("Chat composer · sending in dark appearance") {
    LoadableChat.Composer(draft: .constant(""), canSend: false,
                     isSending: true, isEditable: true, send: {})
        .padding(16)
        .preferredColorScheme(.dark)
        .demoPreviewSize(width: 440, height: 160)
}
#endif
