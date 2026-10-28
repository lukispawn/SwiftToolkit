#if DEBUG
import Testing
@testable import Loadable

@MainActor
private func loadedChat(window: LoadableChat.Window = .middle, seedCount: Int = 90,
                        failures: Set<LoadableChat.Failure> = []) async throws -> LoadableChat.ViewModel {
    let model = LoadableChat.ViewModel(source: LoadableChat.Source(seedCount: seedCount, failures: failures, delay: .zero), window: window)
    model.startIfNeeded()
    let request = try #require(model.history.requestTask)
    _ = try await request.value
    return model
}

@MainActor
@Suite("Chat pagination and live message composition", .timeLimit(.minutes(1)))
struct ChatModelTests {
    @Test func bothDirectionsPreserveOrderAndOppositeCursor() async throws {
        let model = try await loadedChat()
        let initial = model.history.items
        let next = model.history.snapshot.nextCursor
        model.history.loadPage(.previous)
        let older = try #require(model.history.requestTask)
        _ = try await older.value
        #expect(model.history.snapshot.nextCursor == next)
        #expect(Array(model.timeline.suffix(initial.count)) == initial)
        let previous = model.history.snapshot.previousCursor
        model.history.loadMore()
        let newer = try #require(model.history.requestTask)
        _ = try await newer.value
        #expect(model.history.snapshot.previousCursor == previous)
        #expect(model.timeline.map(\.sequence) == model.timeline.map(\.sequence).sorted())
        #expect(Set(model.timeline.map(\.id)).count == model.timeline.count)
    }

    @Test func sendingFromHistoricalWindowKeepsCursorsAndHidesTheGap() async throws {
        let model = try await loadedChat()
        let before = model.history.snapshot.previousCursor
        let after = model.history.snapshot.nextCursor
        let original = model.timeline
        model.draft = "  A new message  "
        let sending = try #require(model.sendDraft())
        let id = try #require(model.outbox.first?.id)
        #expect(model.outbox.first?.delivery == .sending)
        #expect(model.draft.isEmpty)
        #expect(model.timeline == original)
        #expect(model.outsideWindowCount == 1)
        await sending.value
        #expect(model.history.snapshot.previousCursor == before)
        #expect(model.history.snapshot.nextCursor == after)
        #expect(model.history.canLoad(.previous))
        #expect(model.history.canLoad(.next))
        #expect(model.outbox.first?.delivery == .sent)
        #expect(model.outbox.first?.text == "A new message")
        model.jumpToLatest()
        let jump = try #require(model.history.requestTask)
        _ = try await jump.value
        #expect(model.timeline.filter { $0.id == id }.count == 1)
        #expect(model.outsideWindowCount == 0)
        #expect(model.isAtLatestWindow)
    }

    @Test func firstMessageInEmptyConversationIsImmediatelyVisibleAndKeepsItsID() async throws {
        let model = try await loadedChat(window: .latest, seedCount: 0)
        #expect(model.history.snapshot.isEmpty)
        model.draft = "Hello, Maya!"
        let sending = try #require(model.sendDraft())
        let pending = try #require(model.timeline.first)
        #expect(pending.delivery == .sending)
        await sending.value
        #expect(model.timeline.count == 1)
        #expect(model.timeline.first?.id == pending.id)
        #expect(model.timeline.first?.delivery == .sent)
        #expect(model.timeline.first?.sequence == 1)
    }

    @Test func failedSendRetriesWithSameIDAndDoesNotResetPagination() async throws {
        let model = try await loadedChat(window: .latest, failures: [.send])
        let previous = model.history.snapshot.previousCursor
        model.draft = "Please retry this message."
        let first = try #require(model.sendDraft())
        await first.value
        let failed = try #require(model.outbox.first)
        guard case .failed = failed.delivery else { Issue.record("Expected a failed send"); return }
        let retry = try #require(model.retrySend(id: failed.id))
        #expect(model.retrySend(id: failed.id) == nil)
        await retry.value
        #expect(model.outbox.first?.id == failed.id)
        #expect(model.timeline.filter { $0.id == failed.id }.count == 1)
        #expect(model.outbox.first?.delivery == .sent)
        #expect(model.history.snapshot.previousCursor == previous)
        #expect(await model.source.sendAttempts == 2)
        #expect(await model.source.messageCount == 91)
        #expect(model.retrySend(id: failed.id) == nil)
    }

    @Test func incomingMessagesWaitBehindGapUntilNewerHistoryIsLoaded() async throws {
        let model = try await loadedChat()
        let originalCount = model.timeline.count
        let incoming = try #require(model.receiveGenerated())
        await incoming.value
        #expect(model.timeline.count == originalCount)
        #expect(model.outsideWindowCount == 1)
        for _ in 0..<10 {
            guard model.history.canLoad(.next) else { break }
            model.history.loadMore()
            let page = try #require(model.history.requestTask)
            _ = try await page.value
        }
        #expect(model.isAtLatestWindow)
        #expect(model.timeline.last?.sequence == 91)
        #expect(model.outsideWindowCount == 0)
        #expect(model.timeline.filter { $0.sequence == 91 }.count == 1)
    }

    @Test func latestIncomingMessageDeduplicatesWhenHistoryFetchIncludesIt() async throws {
        let model = try await loadedChat(window: .latest)
        let received = try #require(model.receiveGenerated())
        await received.value
        let live = try #require(model.timeline.last)
        #expect(live.sender == .maya)
        model.jumpToLatest()
        let reload = try #require(model.history.requestTask)
        _ = try await reload.value
        #expect(model.history.items.contains { $0.id == live.id })
        #expect(model.timeline.filter { $0.id == live.id }.count == 1)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func pageRetryPreservesConversationAndSurvivesAnOutgoingSend(direction: LoadableCollection.Direction) async throws {
        let model = try await loadedChat(failures: [.older, .newer])
        let initial = model.history.items
        model.history.loadPage(direction)
        let failed = try #require(model.history.requestTask)
        _ = await failed.result
        #expect(model.history.lastError != nil)
        #expect(model.history.items == initial)
        model.draft = "Sending while a page is unavailable."
        let sending = try #require(model.sendDraft())
        await sending.value
        #expect(model.history.canRetry)
        #expect(model.history.lastError != nil)
        model.history.retry()
        let retry = try #require(model.history.requestTask)
        _ = try await retry.value
        let calls = await model.source.calls
        #expect(calls[1] == calls[2])
        #expect(model.history.lastError == nil)
        #expect(initial.allSatisfy { item in model.history.items.contains { $0.id == item.id } })
    }

    @Test func sendingWhileAnOlderPageIsSuspendedDoesNotCancelIt() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(delay: .seconds(1), clock: clock)
        let model = LoadableChat.ViewModel(source: source)
        model.startIfNeeded()
        let initial = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value
        let next = model.history.snapshot.nextCursor
        model.history.loadPage(.previous)
        let page = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(2)
        model.draft = "Send during pagination"
        let sending = try #require(model.sendDraft())
        await clock.sleeps.waitForCalls(3)
        #expect(!page.isCancelled)
        await clock.sleeps.complete(2, .success(()))
        await sending.value
        #expect(!page.isCancelled)
        #expect(model.history.snapshot.phase.isLoading)
        await clock.sleeps.complete(1, .success(()))
        _ = try await page.value
        #expect(model.history.snapshot.nextCursor == next)
        #expect(model.history.items.count == 24)
        #expect(model.outbox.first?.delivery == .sent)
        #expect(model.outsideWindowCount == 1)
    }

    @Test func cancelledSendCannotClearOrOverwriteItsNewRetry() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(delay: .seconds(1), clock: clock)
        let model = LoadableChat.ViewModel(source: source, window: .latest)
        model.startIfNeeded()
        let initial = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value
        model.draft = "Cancel and retry"
        let old = try #require(model.sendDraft())
        let id = try #require(model.outbox.first?.id)
        await clock.sleeps.waitForCalls(2)
        model.stop()
        let retry = try #require(model.retrySend(id: id))
        await clock.sleeps.waitForCalls(3)
        await clock.sleeps.complete(1, .success(()))
        await old.value
        #expect(model.retrySend(id: id) == nil)
        #expect(model.outbox.first?.delivery == .sending)
        await clock.sleeps.complete(2, .success(()))
        await retry.value
        #expect(model.outbox.first?.delivery == .sent)
        #expect(await source.messageCount == 91)
    }

    @Test func liveTailSurvivesAnOlderPageCapturedBeforeTheEvent() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(seedCount: 24, pageSize: 6, delay: .seconds(1), clock: clock)
        let model = LoadableChat.ViewModel(source: source, window: .latest)
        model.startIfNeeded()
        let initial = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value
        model.history.loadPage(.previous)
        let older = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(2)
        let event = try #require(model.receiveGenerated())
        await event.value
        let incoming = try #require(model.timeline.last)
        #expect(incoming.sequence == 25)
        #expect(!older.isCancelled)
        await clock.sleeps.complete(1, .success(()))
        _ = try await older.value
        #expect(model.isAtLatestWindow)
        #expect(model.history.items.map(\.sequence) == Array(13...24))
        #expect(model.timeline.map(\.sequence) == Array(13...25))
        #expect(model.timeline.filter { $0.id == incoming.id }.count == 1)
    }

    @Test func modelDeallocatesAndCancelsItsPendingSend() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(delay: .seconds(1), clock: clock)
        var model: LoadableChat.ViewModel? = .init(source: source, window: .latest)
        model?.startIfNeeded()
        let initial = try #require(model?.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        await clock.sleeps.complete(0, .success(()))
        _ = try await initial.value
        model?.draft = "Release during send"
        let task = try #require(model?.sendDraft())
        await clock.sleeps.waitForCalls(2)
        let weakModel = WeakReference(model)
        model = nil
        #expect(weakModel.value == nil)
        await clock.sleeps.complete(1, .success(()))
        await task.value
        #expect(await source.messageCount == 90)
        #expect(await clock.sleeps.cancelledCalls == [1])
    }

    @Test func resumingCancelledInitialLoadKeepsTheSelectedWindow() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(delay: .seconds(1), clock: clock)
        let model = LoadableChat.ViewModel(source: source)
        model.jumpToLatest()
        let cancelled = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(1)
        model.stop()
        model.startIfNeeded()
        let resumed = try #require(model.history.requestTask)
        await clock.sleeps.waitForCalls(2)
        model.startIfNeeded()
        #expect(await source.calls.count == 2)
        #expect(await source.calls.last?.query == .latest)
        await clock.sleeps.complete(0, .success(()))
        _ = await cancelled.result
        #expect(model.history.snapshot.phase.isLoading)
        await clock.sleeps.complete(1, .success(()))
        _ = try await resumed.value
        #expect(model.isAtLatestWindow)
        #expect(model.timeline.last?.sequence == 90)
    }

    @Test func emptyDraftAndUnloadedHistoryDoNotStartSending() async throws {
        let model = LoadableChat.ViewModel(source: LoadableChat.Source(delay: .zero))
        model.draft = "Hello"
        #expect(model.sendDraft() == nil)
        let ready = try await loadedChat(window: .latest)
        ready.draft = "  \n "
        #expect(ready.sendDraft() == nil)
        #expect(await ready.source.sendAttempts == 0)
        ready.generateDraft()
        #expect(ready.canSend)
    }

    @Test func frozenConversationDoesNotRunCommands() async {
        let source = LoadableChat.Source(delay: .zero)
        let model = LoadableChat.ViewModel(source: source, frozen: .loaded([.generated(1)]))
        model.startIfNeeded()
        model.jumpToLatest()
        model.draft = "No network"
        #expect(model.sendDraft() == nil)
        #expect(model.receiveGenerated() == nil)
        #expect(model.retryAction(for: "history-1") == nil)
        #expect(model.history.requestTask == nil)
        #expect(await source.calls.isEmpty)
        #expect(model.timeline.count == 1)
    }
}
#endif
