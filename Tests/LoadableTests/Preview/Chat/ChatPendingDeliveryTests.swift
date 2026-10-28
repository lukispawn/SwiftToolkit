#if DEBUG
import Testing
@testable import Loadable

@MainActor
@Suite("Chat pending delivery", .timeLimit(.minutes(1)))
struct ChatPendingDeliveryTests {
    @Test("Pending messages stay local until the remote write finishes", arguments: [false, true])
    func pendingMessageIsNotPersistedBeforeAcknowledgement(remoteWriteFails: Bool) async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(failures: remoteWriteFails ? [.send] : [], delay: .seconds(3), clock: clock)
        let model = LoadableChat.ViewModel(source: source, window: .latest)
        model.startIfNeeded()
        let initial = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value

        model.draft = "Show this before the remote save finishes."
        let sending = try #require(model.sendDraft())
        let pending = try #require(model.timeline.last)
        #expect(pending.delivery == .sending)
        #expect(model.draft.isEmpty)
        #expect(!model.history.items.contains { $0.id == pending.id })
        await clock.sleeps.waitForCalls(2)
        #expect(await source.messageCount == 90)

        // A server read completed while the write is suspended cannot see the outbox.
        let beforeSave = Task { try await source.fetchPage(query: .latest, cursor: nil, direction: .next) }
        await clock.sleeps.waitForCalls(3)
        await clock.sleeps.complete(2, .success(()))
        let before = try await beforeSave.value
        #expect(!before.items.contains { $0.id == pending.id })
        #expect(model.timeline.last?.delivery == .sending)

        await clock.sleeps.complete(1, .success(()))
        await sending.value
        let final = try #require(model.timeline.last)
        #expect(final.id == pending.id)
        #expect(final.text == pending.text)
        #expect(model.timeline.filter { $0.id == pending.id }.count == 1)
        #expect(!model.history.items.contains { $0.id == pending.id })
        if remoteWriteFails {
            guard case .failed = final.delivery else { Issue.record("Expected a failed local message"); return }
            #expect(await source.messageCount == 90)
        } else {
            #expect(final.delivery == .sent)
            #expect(await source.messageCount == 91)
        }

        let afterSave = Task { try await source.fetchPage(query: .latest, cursor: nil, direction: .next) }
        await clock.sleeps.waitForCalls(4)
        await clock.sleeps.complete(3, .success(()))
        let after = try await afterSave.value
        #expect(after.items.filter { $0.id == pending.id }.count == (remoteWriteFails ? 0 : 1))
    }

    @Test func frozenPendingPreviewKeepsItsOutboxSeparateAndDoesNotSendOnExit() async throws {
        let history = [LoadableChat.Message.generated(1), .generated(2)]
        var pending = LoadableChat.Message.generated(3, sender: .me)
        pending.delivery = .sending
        let model = LoadableChat.ViewModel(previewSnapshot: .loaded(history), outbox: [pending])
        let original = model.timeline
        #expect(model.history.items == history)
        #expect(model.timeline.last == pending)
        model.startIfNeeded()
        model.jumpToLatest()
        model.stop()
        model.draft = "A frozen fixture cannot send."
        #expect(model.sendDraft() == nil)
        #expect(model.timeline == original)
        #expect(await model.source.sendAttempts == 0)
        #expect(await model.source.calls.isEmpty)
    }
}
#endif
