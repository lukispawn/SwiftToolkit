import CoreGraphics
import Testing
@testable import Loadable

@MainActor
@Suite("LoadableImageModel", .timeLimit(.minutes(1)))
struct LoadableImageModelTests {
    typealias Counting = CountingImageSource<DelayedImageSource<StaticImageSource>>

    private func makeSource(delay: Duration) -> Counting {
        CountingImageSource(
            DelayedImageSource(base: StaticImageSource(gray: 0.5, size: CGSize(width: 4, height: 4)), delay: delay))
    }

    private func key(_ content: String, _ variant: Int = 0) -> PreviewImageKey {
        PreviewImageKey(contentID: content, variant: variant)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            #expect(ContinuousClock.now < deadline, "condition not reached")
            if ContinuousClock.now >= deadline { return }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func nilKeyShowsNoneAndDoesNotLoad() async {
        let source = makeSource(delay: .zero)
        let model = LoadableImageModel(source: source, debounce: .milliseconds(10))
        await model.update(key: nil)
        #expect(model.isNone)
        #expect(await source.fetchCount == 0)
    }

    @Test func firstLoadHasNoDebounce() async {
        let model = LoadableImageModel(source: makeSource(delay: .zero), debounce: .seconds(30))
        await model.update(key: key("a"))
        #expect(model.image != nil)
        #expect(!model.isLoading)
    }

    @Test func sameContentKeepsPreviousImageWhileLoading() async throws {
        let model = LoadableImageModel(source: makeSource(delay: .milliseconds(150)), debounce: .milliseconds(1))
        await model.update(key: key("a"))
        let first = try #require(model.image)
        let task = Task { await model.update(key: key("a", 1)) }
        try await waitUntil { model.isLoading }
        #expect(model.image?.cgImage === first.cgImage)
        await task.value
        #expect(model.image?.cgImage !== first.cgImage)
        #expect(!model.isLoading)
    }

    @Test func differentContentClearsImageImmediately() async throws {
        let model = LoadableImageModel(source: makeSource(delay: .milliseconds(150)), debounce: .seconds(30))
        await model.update(key: key("a"))
        #expect(model.image != nil)
        let task = Task { await model.update(key: key("b")) }
        try await waitUntil { model.isLoading }
        #expect(model.image == nil)
        await task.value
        #expect(model.image != nil)
    }

    @Test func sameContentChangeIsDebounced() async {
        let source = makeSource(delay: .zero)
        let model = LoadableImageModel(source: source, debounce: .milliseconds(150))
        await model.update(key: key("a"))
        let first = Task { await model.update(key: key("a", 1)) }
        try? await Task.sleep(for: .milliseconds(10))
        first.cancel()
        await first.value
        await model.update(key: key("a", 2))
        #expect(await source.fetchCount == 2)
    }

    @Test func rapidFlipABAEndsOnAWithoutReload() async throws {
        let source = makeSource(delay: .zero)
        let model = LoadableImageModel(source: source, debounce: .milliseconds(150))
        await model.update(key: key("a"))
        let original = try #require(model.image)
        let toB = Task { await model.update(key: key("a", 1)) }
        try await Task.sleep(for: .milliseconds(10))
        toB.cancel()
        await toB.value
        await model.update(key: key("a"))
        #expect(model.image?.cgImage === original.cgImage)
        #expect(!model.isLoading)
        #expect(await source.fetchCount == 1)
    }

    @Test func cancellationDoesNotSetFailed() async throws {
        let model = LoadableImageModel(source: makeSource(delay: .seconds(30)), debounce: .milliseconds(1))
        let task = Task { await model.update(key: key("a")) }
        try await waitUntil { model.isLoading }
        task.cancel()
        await task.value
        #expect(model.error == nil)
    }

    @Test func errorSetsFailedAndRetryReloads() async {
        let source = CountingImageSource(FailingImageSource(error: LoadableImageError.undecodable))
        let model = LoadableImageModel(source: source, debounce: .milliseconds(1))
        await model.update(key: key("a"))
        #expect(model.error as? LoadableImageError == .undecodable)
        await model.retry()
        #expect(model.error as? LoadableImageError == .undecodable)
        #expect(await source.fetchCount == 2)
    }

    @Test func reappearingWithSameKeyDoesNotReload() async {
        let source = makeSource(delay: .zero)
        let model = LoadableImageModel(source: source, debounce: .milliseconds(1))
        await model.update(key: key("a"))
        await model.update(key: key("a"))
        #expect(await source.fetchCount == 1)
    }
}
