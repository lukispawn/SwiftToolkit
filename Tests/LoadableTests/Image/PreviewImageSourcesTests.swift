import CoreGraphics
import Testing
@testable import Loadable

@Suite("Preview image sources", .timeLimit(.minutes(1)))
struct PreviewImageSourcesTests {
    private let key = PreviewImageKey(contentID: "a")

    @Test func staticSourceReturnsImageOfConfiguredSize() async throws {
        let source = StaticImageSource(gray: 0.3, size: CGSize(width: 8, height: 6))
        let value = try await source.fetch(query: key)
        #expect(value.cgImage.width == 8)
        #expect(value.cgImage.height == 6)
    }

    @Test func staticSourceThrowsMissingKeyForNil() async {
        let source = StaticImageSource(gray: 0.3, size: CGSize(width: 8, height: 8))
        await #expect(throws: LoadableImageError.missingKey) { try await source.fetch(query: nil) }
    }

    @Test func delayedSourceThrowsCancellationWhenCancelled() async {
        let source = DelayedImageSource(
            base: StaticImageSource(gray: 0.5, size: CGSize(width: 4, height: 4)), delay: .seconds(30))
        let task = Task { try await source.fetch(query: key) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func failingSourceThrowsConfiguredError() async {
        let source = FailingImageSource(error: LoadableImageError.undecodable)
        await #expect(throws: LoadableImageError.undecodable) { try await source.fetch(query: key) }
    }

    @Test func countingSourceTracksCountAndPeakConcurrency() async throws {
        let counting = CountingImageSource(
            DelayedImageSource(
                base: StaticImageSource(gray: 0.5, size: CGSize(width: 4, height: 4)),
                delay: .milliseconds(100)))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<2 {
                group.addTask { _ = try await counting.fetch(query: PreviewImageKey(contentID: "k\(index)")) }
            }
            try await group.waitForAll()
        }
        #expect(await counting.fetchCount == 2)
        #expect(await counting.maxConcurrent == 2)
    }
}
