import CoreGraphics
import Testing
@testable import Loadable

@Suite("CachedImageSource", .timeLimit(.minutes(1)))
struct CachedImageSourceTests {
    private func counting(delay: Duration)
        -> CountingImageSource<DelayedImageSource<StaticImageSource>>
    {
        CountingImageSource(
            DelayedImageSource(base: StaticImageSource(gray: 0.5, size: CGSize(width: 4, height: 4)), delay: delay))
    }

    @Test func wrapsBaseAndCachesByKey() async throws {
        let base = counting(delay: .milliseconds(1))
        let cached = CachedImageSource(base, cache: LoadableImageCache())
        let key = PreviewImageKey(contentID: "a")
        let first = try await cached.fetch(query: key)
        let second = try await cached.fetch(query: key)
        #expect(first.cgImage === second.cgImage)
        #expect(await base.fetchCount == 1)
    }

    @Test func missingKeyThrowsMissingKey() async {
        let cached = CachedImageSource(counting(delay: .zero), cache: LoadableImageCache())
        await #expect(throws: LoadableImageError.missingKey) { try await cached.fetch(query: nil) }
    }

    @Test func sourcesWithEqualKeysDoNotShareImages() async throws {
        let cache = LoadableImageCache()
        let a = CachedImageSource(counting(delay: .zero), cache: cache, namespace: "A")
        let b = CachedImageSource(counting(delay: .zero), cache: cache, namespace: "B")
        let key = PreviewImageKey(contentID: "a")
        #expect(try await a.fetch(query: key).cgImage !== b.fetch(query: key).cgImage)
    }

    @Test func stress500ConcurrentRequestsSameKey() async throws {
        let base = counting(delay: .milliseconds(10))
        let cached = CachedImageSource(base, cache: LoadableImageCache())
        let key = PreviewImageKey(contentID: "same")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<500 { group.addTask { _ = try await cached.fetch(query: key) } }
            try await group.waitForAll()
        }
        #expect(await base.fetchCount == 1)
    }

    @Test func stressManyKeysWithRapidCancellation() async throws {
        let base = counting(delay: .milliseconds(5))
        let cached = CachedImageSource(base, cache: LoadableImageCache(maxConcurrentLoads: 2))
        let tasks = (0..<500).map { index in
            Task { try await cached.fetch(query: PreviewImageKey(contentID: "k\(index)")) }
        }
        for (index, task) in tasks.enumerated() where index % 5 != 0 { task.cancel() }
        var survivors = 0
        for (index, task) in tasks.enumerated() {
            if let _ = try? await task.value { survivors += 1 } else { #expect(index % 5 != 0) }
        }
        #expect(survivors > 0)
        #expect(await base.maxConcurrent <= 2)
        // No leaked slot: a fresh request still completes.
        _ = try await cached.fetch(query: PreviewImageKey(contentID: "after"))
    }

    @Test func stressResizeLikeKeyChurn() async throws {
        let base = counting(delay: .milliseconds(5))
        let cached = CachedImageSource(base, cache: LoadableImageCache())
        var previous: Task<LoadableImageValue, any Error>?
        for variant in 0..<1000 {
            previous?.cancel()
            previous = Task {
                try await cached.fetch(query: PreviewImageKey(contentID: "same", variant: variant))
            }
            if variant % 10 == 0 { await Task.yield() }
        }
        let last = try #require(previous)
        _ = try await last.value
        #expect(await base.maxConcurrent <= 2)
    }
}
