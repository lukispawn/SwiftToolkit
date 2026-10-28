import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Clock-driven query scheduling", .timeLimit(.minutes(1)))
struct QueryDebouncerTests {
    @Test func onlyLatestQueryCommitsAfterBurst() async throws {
        let clock = ControlledClock()
        var committed: [String] = []
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { query, _ in committed.append(query) }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let first = try #require(sut.scheduledTask)
        sut.submit("B")
        await clock.sleeps.waitForCalls(2)
        let second = try #require(sut.scheduledTask)
        await clock.sleeps.complete(0, .success(()))
        await first.value
        #expect(sut.pendingQuery == "B")
        #expect(committed.isEmpty)
        await clock.sleeps.complete(1, .success(()))
        await second.value
        #expect(committed == ["B"])
        #expect(!sut.isWaiting)
    }

    @Test func configuredDelayReachesClockExactly() async throws {
        let clock = ControlledClock()
        let sut = LoadableQueryDebouncer<String>(delay: .milliseconds(450), clock: clock) { _, _ in }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let task = try #require(sut.scheduledTask)
        #expect(await clock.sleeps.queries == [clock.now.advanced(by: .milliseconds(450))])
        await clock.sleeps.complete(0, .success(()))
        await task.value
    }

    @Test func immediateSubmissionInvalidatesPendingWakeup() async throws {
        let clock = ControlledClock()
        var submissions: [LoadableQueryDebouncer<String>.Submission] = []
        var queries: [String] = []
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { query, submission in
            queries.append(query)
            submissions.append(submission)
        }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let old = try #require(sut.scheduledTask)
        sut.submitNow("B")
        #expect(!sut.isWaiting)
        await clock.sleeps.complete(0, .success(()))
        await old.value
        #expect(queries == ["B"])
        #expect(submissions == [.immediate])
    }

    @Test func debouncedSubmissionIsDistinguishable() async throws {
        let clock = ControlledClock()
        var submission: LoadableQueryDebouncer<String>.Submission?
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { _, mode in submission = mode }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let task = try #require(sut.scheduledTask)
        await clock.sleeps.complete(0, .success(()))
        await task.value
        #expect(submission == .debounced)
    }

    @Test func cancelBeforeExecutionDoesNotAskClockToSleep() async throws {
        let clock = ControlledClock()
        var committed = false
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { _, _ in committed = true }
        sut.submit("A")
        let task = try #require(sut.scheduledTask)
        sut.cancelPending()
        await task.value
        #expect(await clock.sleeps.queries.isEmpty)
        #expect(!committed)
        #expect(!sut.isWaiting)
    }

    @Test func cancelDuringSleepPreventsCommit() async throws {
        let clock = ControlledClock()
        var committed = false
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { _, _ in committed = true }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let task = try #require(sut.scheduledTask)
        sut.cancelPending()
        await clock.sleeps.complete(0, .success(()))
        await task.value
        #expect(!committed)
        #expect(!sut.isWaiting)
    }

    @Test func sleepFailureClearsWaitingState() async throws {
        let clock = ControlledClock()
        var committed = false
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { _, _ in committed = true }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let task = try #require(sut.scheduledTask)
        await clock.sleeps.complete(0, .failure(.rejected))
        await task.value
        #expect(!sut.isWaiting)
        #expect(sut.scheduledTask == nil)
        #expect(!committed)
    }

    @Test func oldSleepFailureDoesNotClearNewPendingQuery() async throws {
        let clock = ControlledClock()
        let sut = LoadableQueryDebouncer<String>(delay: .seconds(1), clock: clock) { _, _ in }
        sut.submit("A")
        await clock.sleeps.waitForCalls(1)
        let old = try #require(sut.scheduledTask)
        sut.submit("B")
        await clock.sleeps.waitForCalls(2)
        let current = try #require(sut.scheduledTask)
        await clock.sleeps.complete(0, .failure(.rejected))
        await old.value
        #expect(sut.pendingQuery == "B")
        await clock.sleeps.complete(1, .success(()))
        await current.value
    }

    @Test func debouncerDeallocatesDuringSleep() async throws {
        let clock = ControlledClock()
        var sut: LoadableQueryDebouncer<String>? = .init(delay: .seconds(1), clock: clock) { _, _ in
            Issue.record("Released debouncer must not commit")
        }
        let weakDebouncer = WeakReference(sut)
        sut?.submit("A")
        await clock.sleeps.waitForCalls(1)
        let task = try #require(sut?.scheduledTask)
        sut = nil
        #expect(weakDebouncer.value == nil)
        await clock.sleeps.complete(0, .success(()))
        await task.value
        #expect(await clock.sleeps.cancelledCalls == [0])
    }

    @Test func waitingStateParticipatesInObservation() async {
        let sut = LoadableQueryDebouncer<String> { _, _ in }
        await confirmation("Pending query is observable") { changed in
            withObservationTracking { _ = sut.isWaiting } onChange: { changed() }
            sut.submit("A")
        }
        sut.cancelPending()
    }
}
