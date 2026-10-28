#if DEBUG
import Foundation

extension LoadableChat {
    struct Message: Identifiable, Sendable, Equatable {
        enum Sender: Sendable { case me, maya }
        enum Delivery: Sendable, Equatable {
            case sending, sent, failed(String)
        }

        let id: String
        let sequence: Int
        let text: String
        let sender: Sender
        let sentAt: Date
        var delivery: Delivery = .sent

        static let baseDate = Date(timeIntervalSince1970: 1_760_000_000)

        static func generated(_ sequence: Int, sender: Sender? = nil) -> Self {
            let sender = sender ?? (sequence % 5 < 2 ? .me : .maya)
            let openings = [
                "I have updated the conversation preview.",
                "The older messages should stay exactly where we left them.",
                "Can we try loading the next part of the history?",
                "Yes, the page boundaries use message IDs instead of offsets.",
                "I am checking how this behaves with a longer message.",
                "That looks good. Let's keep the scrolling predictable.",
                "A new message can arrive while we are reading earlier replies.",
                "We should be able to retry without duplicating a message."
            ]
            let extra = sequence % 4 == 0
                ? " The content can wrap across several lines, just like a real conversation. We can still load earlier history and send a reply at the same time."
                : ""
            return Self(id: "history-\(sequence)", sequence: sequence,
                        text: openings[(sequence - 1) % openings.count] + extra,
                        sender: sender, sentAt: baseDate.addingTimeInterval(Double(sequence * 180)))
        }
    }

    enum Query: Sendable, Equatable {
        case latest
        case around(Int)
    }

    enum Cursor: Sendable, Equatable {
        case before(Int)
        case after(Int)
    }

    enum Failure: String, Error, LocalizedError, Sendable, Hashable {
        case initial, older, newer, send

        var errorDescription: String? {
            switch self {
            case .initial: "The conversation could not be loaded. Retry to connect."
            case .older: "Earlier messages could not be loaded. Your conversation is still available."
            case .newer: "Newer messages could not be loaded. Retry this page to continue."
            case .send: "Message not sent. Retry to deliver it once."
            }
        }
    }
}
#endif
