import CoreGraphics
import Foundation
import Testing
@testable import Loadable

@Suite("ImageURLSource", .timeLimit(.minutes(1)))
struct ImageURLSourceTests {
    private func key(_ url: URL, points: CGFloat = 64, scale: CGFloat = 2) -> ImageURLKey {
        ImageURLKey(url: url, size: CGSize(width: points, height: points), scale: scale)
    }

    @Test func decodesLocalPNGDownscaledToKeySize() async throws {
        let url = try TestImage.writeTemp(TestImage.pngData(width: 1000, height: 1000), ext: "png")
        let value = try await ImageURLSource().fetch(query: key(url))
        #expect(max(value.cgImage.width, value.cgImage.height) <= 128)
        #expect(value.cgImage.width > 0)
        #expect(value.scale == 2)
    }

    @Test func doesNotUpscaleSmallImages() async throws {
        let url = try TestImage.writeTemp(TestImage.pngData(width: 10, height: 10), ext: "png")
        let value = try await ImageURLSource().fetch(query: key(url, points: 256))
        #expect(value.cgImage.width == 10)
    }

    @Test func missingLocalFileThrows() async {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).png")
        await #expect(throws: (any Error).self) { try await ImageURLSource().fetch(query: key(url)) }
    }

    @Test func nonImageDataThrowsUndecodable() async throws {
        let url = try TestImage.writeTemp(Data("not an image".utf8), ext: "png")
        await #expect(throws: LoadableImageError.undecodable) { try await ImageURLSource().fetch(query: key(url)) }
    }

    @Test func remoteSuccessDecodes() async throws {
        let url = URL(string: "https://stub.test/\(UUID().uuidString).png")!
        StubURLProtocol.register(url, status: 200, data: TestImage.pngData(width: 40, height: 20))
        let value = try await ImageURLSource(session: StubURLProtocol.session()).fetch(query: key(url))
        #expect(value.cgImage.width == 40)
    }

    @Test func remoteBadStatusThrows() async {
        let url = URL(string: "https://stub.test/\(UUID().uuidString).png")!
        StubURLProtocol.register(url, status: 404, data: Data())
        await #expect(throws: LoadableImageError.badStatus(404)) {
            try await ImageURLSource(session: StubURLProtocol.session()).fetch(query: key(url))
        }
    }

    @Test func remoteNonImageBodyThrowsUndecodable() async {
        let url = URL(string: "https://stub.test/\(UUID().uuidString).png")!
        StubURLProtocol.register(url, status: 200, data: Data("<html>".utf8))
        await #expect(throws: LoadableImageError.undecodable) {
            try await ImageURLSource(session: StubURLProtocol.session()).fetch(query: key(url))
        }
    }

    @Test func nilKeyThrowsMissingKey() async {
        await #expect(throws: LoadableImageError.missingKey) { try await ImageURLSource().fetch(query: nil) }
    }

    @Test func contentIDIsURLIgnoringSizeAndScale() {
        let url = URL(string: "https://example.com/a.png")!
        #expect(key(url, points: 64).contentID == key(url, points: 500, scale: 3).contentID)
        #expect(key(url).contentID == url)
    }

    @Test func nearbySizesShareKey() {
        let url = URL(string: "https://example.com/a.png")!
        #expect(key(url, points: 65) == key(url, points: 128))
        #expect(key(url, points: 65) != key(url, points: 129))
    }

    @Test func decodesToFillSizeWhenAspectRatioDiffers() async throws {
        let url = try TestImage.writeTemp(TestImage.pngData(width: 1000, height: 2000), ext: "png")
        // 64 x 64 pt at 2x is a 128 px square; filling it needs at least 128 px in both directions.
        let value = try await ImageURLSource().fetch(query: key(url))
        #expect(value.cgImage.width >= 128)
        #expect(value.cgImage.height >= 128)
    }
}
