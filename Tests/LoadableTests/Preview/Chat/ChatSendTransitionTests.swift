#if DEBUG
import Foundation
import Testing
@testable import Loadable

@MainActor
@Suite("Chat composer-to-bubble transition", .timeLimit(.minutes(1)))
struct ChatSendTransitionTests {
    private let field = CGRect(x: 16, y: 500, width: 280, height: 52)

    @Test func repeatedSendsIgnoreAnOlderAnimationCompletion() throws {
        var state = LoadableChat.SendTransition()
        let message = LoadableChat.Message.generated(1, sender: .me)
        state.begin(message: message, sourceFrame: field, reduceMotion: false, followsLatest: true)
        let first = try #require(state.flight)
        #expect(!first.isRunning)
        state.markRunning(id: first.id)
        #expect(state.flight?.isRunning == true)
        state.begin(message: message, sourceFrame: field, reduceMotion: false, followsLatest: true)
        let replacement = try #require(state.flight)
        #expect(replacement.id != first.id)
        #expect(replacement.message.id == message.id)
        #expect(replacement.sourceFrame == field)
        state.markRunning(id: first.id)
        #expect(state.flight?.isRunning == false)
        state.finish(id: first.id)
        #expect(state.flight?.id == replacement.id)
        state.finish(id: replacement.id)
        #expect(state.flight == nil)
    }

    @Test(arguments: ["reduceMotion", "historicalWindow", "missingGeometry", "infiniteGeometry"])
    func unsupportedFlightRestoresTheNormalBubble(reason: String) {
        var state = LoadableChat.SendTransition()
        let message = LoadableChat.Message.generated(1, sender: .me)
        state.begin(message: message, sourceFrame: field, reduceMotion: false, followsLatest: true)
        let frame: CGRect = switch reason {
        case "missingGeometry": .zero
        case "infiniteGeometry": .infinite
        default: field
        }
        state.begin(message: message, sourceFrame: frame,
                    reduceMotion: reason == "reduceMotion", followsLatest: reason != "historicalWindow")
        #expect(state.flight == nil)
    }

    @Test func cancellingVisualStateMakesLateCompletionHarmless() throws {
        var state = LoadableChat.SendTransition()
        state.begin(message: .generated(1), sourceFrame: field, reduceMotion: false, followsLatest: true)
        let flight = try #require(state.flight)
        state.cancel()
        state.finish(id: flight.id)
        #expect(state.flight == nil)
    }

    @Test func landingDoesNotAcknowledgeOrCancelThePendingRemoteWrite() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(delay: .seconds(3), clock: clock)
        let model = LoadableChat.ViewModel(source: source, window: .latest)
        model.startIfNeeded()
        let initial = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value

        model.draft = "The animation can finish before persistence."
        let sending = try #require(model.sendDraft())
        let message = try #require(model.timeline.last)
        var state = LoadableChat.SendTransition()
        state.begin(message: message, sourceFrame: field, reduceMotion: false, followsLatest: true)
        let flight = try #require(state.flight)
        await clock.sleeps.waitForCalls(2)
        state.finish(id: flight.id)
        #expect(state.flight == nil)
        #expect(model.timeline.last?.delivery == .sending)
        #expect(await source.messageCount == 90)
        #expect(!sending.isCancelled)

        await clock.sleeps.complete(1, .success(()))
        await sending.value
        #expect(model.timeline.last?.id == message.id)
        #expect(model.timeline.last?.delivery == .sent)
        #expect(await source.messageCount == 91)
    }
}
#endif
