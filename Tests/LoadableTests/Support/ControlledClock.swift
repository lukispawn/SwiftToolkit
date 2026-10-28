/// A clock spy: `now` is fixed so requested deadlines are exact and inspectable.
/// Tests explicitly release each sleep; cancellation is deliberately ignored to
/// exercise stale-wakeup protection independently of a real clock's cooperation.
struct ControlledClock: Clock {
    let now = ContinuousClock.now
    var minimumResolution: Duration { .nanoseconds(1) }
    let sleeps = ControlledValueSource<Void, ContinuousClock.Instant>()

    func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
        try await sleeps.fetch(query: deadline)
    }
}
