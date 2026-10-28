#if DEBUG
import SwiftUI

extension LoadableChat {
    /// Transient presentation state. Finishing a flight never acknowledges delivery.
    struct SendTransition {
        static let coordinateSpace = "LoadableChatSendTransition"

        struct Flight: Identifiable {
            let id = UUID()
            let message: Message
            let sourceFrame: CGRect
            var isRunning = false
        }

        private(set) var flight: Flight?

        mutating func begin(message: Message, sourceFrame: CGRect,
                            reduceMotion: Bool, followsLatest: Bool) {
            flight = nil
            guard !reduceMotion, followsLatest,
                  !sourceFrame.isNull, !sourceFrame.isInfinite,
                  sourceFrame.width > 0, sourceFrame.height > 0,
                  sourceFrame.width.isFinite, sourceFrame.height.isFinite,
                  sourceFrame.origin.x.isFinite, sourceFrame.origin.y.isFinite else { return }
            flight = Flight(message: message, sourceFrame: sourceFrame)
        }

        mutating func finish(id: UUID) {
            guard flight?.id == id else { return }
            flight = nil
        }

        mutating func markRunning(id: UUID) {
            guard flight?.id == id else { return }
            flight?.isRunning = true
        }

        mutating func cancel() { flight = nil }
    }

    struct BubbleAnchorKey: PreferenceKey {
        static var defaultValue: [String: Anchor<CGRect>] { [:] }

        static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }

    struct SendFlightView: View {
        let flight: SendTransition.Flight
        let destination: CGRect
        let completion: (UUID) -> Void
        @State private var arrived = false

        var body: some View {
            let frame = arrived ? destination : flight.sourceFrame
            Text(flight.message.text)
                .font(.body)
                .foregroundStyle(arrived ? Color.white : .primary)
                .padding(.horizontal, arrived ? 14 : 16)
                .padding(.vertical, arrived ? 11 : 14)
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .background(.indigo.opacity(arrived ? 1 : 0))
                .clipShape(.rect(cornerRadius: arrived ? 18 : 26))
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(.smooth(duration: 0.32), completionCriteria: .removed) {
                        arrived = true
                    } completion: {
                        completion(flight.id)
                    }
                }
        }
    }
}
#endif
