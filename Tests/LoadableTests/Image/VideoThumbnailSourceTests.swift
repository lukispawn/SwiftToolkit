import CoreGraphics
import Foundation
import Testing
@testable import Loadable

// A decoding test against a real video needs a fixture; only key rules and failure paths are covered here.
@Suite("VideoThumbnailSource", .timeLimit(.minutes(1)))
struct VideoThumbnailSourceTests {
    private let url = URL(string: "https://example.com/clip.mp4")!
    private let size = CGSize(width: 100, height: 100)

    @Test func contentIDIgnoresTimeSizeAndScale() {
        let a = VideoThumbnailKey(url: url, time: .seconds(1), size: size, scale: 2)
        let b = VideoThumbnailKey(url: url, time: .seconds(9), size: CGSize(width: 400, height: 300), scale: 3)
        #expect(a.contentID == b.contentID)
        #expect(a.contentID == url)
    }

    @Test func keysDifferByTimeAndRoundedSize() {
        let base = VideoThumbnailKey(url: url, time: .seconds(1), size: size, scale: 2)
        #expect(base != VideoThumbnailKey(url: url, time: .seconds(2), size: size, scale: 2))
        #expect(base != VideoThumbnailKey(url: url, time: .seconds(1), size: CGSize(width: 300, height: 100), scale: 2))
        #expect(base == VideoThumbnailKey(url: url, time: .seconds(1), size: CGSize(width: 110, height: 90), scale: 2))
    }

    @Test func timeIsStoredInMilliseconds() {
        #expect(VideoThumbnailKey(url: url, time: .milliseconds(1500), size: size, scale: 1).timeMilliseconds == 1500)
    }

    @Test func missingFileThrowsUndecodable() async {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).mp4")
        let key = VideoThumbnailKey(url: missing, size: size, scale: 1)
        await #expect(throws: LoadableImageError.undecodable) { try await VideoThumbnailSource().fetch(query: key) }
    }

    @Test func nilKeyThrowsMissingKey() async {
        await #expect(throws: LoadableImageError.missingKey) { try await VideoThumbnailSource().fetch(query: nil) }
    }
}
