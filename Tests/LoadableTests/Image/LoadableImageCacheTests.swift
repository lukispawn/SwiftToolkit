import CoreGraphics
import Testing
@testable import Loadable

actor LoadProbe {
    private(set) var started = 0
    private(set) var active = 0
    private(set) var peak = 0
    private(set) var cancelled = 0

    func begin() {
        started += 1
        active += 1
        peak = max(peak, active)
    }
    func end() { active -= 1 }
    func markCancelled() { cancelled += 1 }

    func waitUntil(timeout: Duration = .seconds(10), _ condition: @Sendable (LoadProbe) async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while await !condition(self) {
            guard clock.now < deadline else { throw ProbeTimeout() }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

struct ProbeTimeout: Error {}

private func image(_ size: Int = 8) -> LoadableImageValue {
    LoadableImageValue(cgImage: TestImage.make(width: size, height: size)!, scale: 1)
}

@Suite("LoadableImageCache", .timeLimit(.minutes(1)))
struct LoadableImageCacheTests {
    @Test func sameKeyLoadsOnce() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        let results = try await withThrowingTaskGroup(of: LoadableImageValue.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try await cache.image(for: "k", namespace: "n") {
                        await probe.begin()
                        try await Task.sleep(for: .milliseconds(50))
                        await probe.end()
                        return image()
                    }
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(await probe.started == 1)
        #expect(Set(results.map { ObjectIdentifier($0.cgImage) }).count == 1)
    }

    @Test func cachedValueIsReturnedWithoutLoading() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        for _ in 0..<3 {
            _ = try await cache.image(for: "k", namespace: "n") {
                await probe.begin(); await probe.end()
                return image()
            }
        }
        #expect(await probe.started == 1)
    }

    @Test func differentKeysRespectConcurrencyLimit() async throws {
        let cache = LoadableImageCache(byteLimit: 100_000_000, maxConcurrentLoads: 2)
        let probe = LoadProbe()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    _ = try await cache.image(for: index, namespace: "n") {
                        await probe.begin()
                        try await Task.sleep(for: .milliseconds(20))
                        await probe.end()
                        return image()
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(await probe.started == 20)
        #expect(await probe.peak <= 2)
    }

    @Test func cancelledLoadReleasesSlot() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000, maxConcurrentLoads: 1)
        let probe = LoadProbe()
        let blocked = Task {
            try await cache.image(for: "a", namespace: "n") {
                await probe.begin()
                defer { Task { await probe.end() } }
                try await Task.sleep(for: .seconds(60))
                return image()
            }
        }
        try await probe.waitUntil { await $0.started >= 1 }
        let next = Task { try await cache.image(for: "b", namespace: "n") { image() } }
        blocked.cancel()
        _ = try await next.value
        await #expect(throws: CancellationError.self) { try await blocked.value }
    }

    @Test func allWaitersCancelCancelsLoad() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        let tasks = (0..<3).map { _ in
            Task {
                try await cache.image(for: "k", namespace: "n") {
                    await probe.begin()
                    do { try await Task.sleep(for: .seconds(60)) } catch {
                        await probe.markCancelled()
                        throw error
                    }
                    return image()
                }
            }
        }
        try await probe.waitUntil { await $0.started >= 1 }
        tasks.forEach { $0.cancel() }
        try await probe.waitUntil { await $0.cancelled >= 1 }
        for task in tasks {
            await #expect(throws: CancellationError.self) { try await task.value }
        }
        #expect(await probe.started == 1)
    }

    @Test func oneCancelledWaiterKeepsSharedLoadAlive() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        let make: @Sendable () async throws -> LoadableImageValue = {
            await probe.begin()
            try await Task.sleep(for: .milliseconds(200))
            return image()
        }
        let first = Task { try await cache.image(for: "k", namespace: "n", load: make) }
        let second = Task { try await cache.image(for: "k", namespace: "n", load: make) }
        try await probe.waitUntil { await $0.started >= 1 }
        try await Task.sleep(for: .milliseconds(20))
        first.cancel()
        _ = try await second.value
        #expect(await probe.started == 1)
    }

    @Test func errorIsNotCached() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        await #expect(throws: LoadableImageError.undecodable) {
            try await cache.image(for: "k", namespace: "n") {
                await probe.begin(); await probe.end()
                throw LoadableImageError.undecodable
            }
        }
        _ = try await cache.image(for: "k", namespace: "n") {
            await probe.begin(); await probe.end()
            return image()
        }
        #expect(await probe.started == 2)
    }

    @Test func namespacesDoNotCollide() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let a = try await cache.image(for: "k", namespace: "A") { image() }
        let b = try await cache.image(for: "k", namespace: "B") { image() }
        #expect(a.cgImage !== b.cgImage)
    }

    @Test func exceedingByteLimitEvictsSomething() async throws {
        let one = image(64).cost
        let cache = LoadableImageCache(byteLimit: one * 2, maxConcurrentLoads: 1)
        let probe = LoadProbe()
        for index in 0..<10 {
            _ = try await cache.image(for: index, namespace: "n") {
                await probe.begin(); await probe.end()
                return image(64)
            }
        }
        for index in 0..<10 {
            _ = try await cache.image(for: index, namespace: "n") {
                await probe.begin(); await probe.end()
                return image(64)
            }
        }
        #expect(await probe.started > 10)
    }

    @Test func removeAllForcesReload() async throws {
        let cache = LoadableImageCache(byteLimit: 10_000_000)
        let probe = LoadProbe()
        let make: @Sendable () async throws -> LoadableImageValue = {
            await probe.begin(); await probe.end()
            return image()
        }
        _ = try await cache.image(for: "k", namespace: "n", load: make)
        await cache.removeAll()
        _ = try await cache.image(for: "k", namespace: "n", load: make)
        #expect(await probe.started == 2)
    }
}
