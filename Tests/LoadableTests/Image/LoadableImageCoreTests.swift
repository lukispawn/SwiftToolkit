import CoreGraphics
import Testing
@testable import Loadable

@Suite("LoadableImage core types", .timeLimit(.minutes(1)))
struct LoadableImageCoreTests {
    @Test func roundedUpToMultipleOf64() {
        #expect(LoadableImageSize.rounded(CGSize(width: 65, height: 1)) == CGSize(width: 128, height: 64))
    }

    @Test func roundedKeepsZero() {
        #expect(LoadableImageSize.rounded(.zero) == .zero)
    }

    @Test func roundedKeepsExactMultiples() {
        #expect(LoadableImageSize.rounded(CGSize(width: 64, height: 128)) == CGSize(width: 64, height: 128))
    }

    @Test func roundedTreatsNegativeAsZero() {
        #expect(LoadableImageSize.rounded(CGSize(width: -5, height: 10)) == CGSize(width: 0, height: 64))
    }

    @Test func valueCostIsBytes() throws {
        let image = try #require(TestImage.make(width: 10, height: 10))
        #expect(LoadableImageValue(cgImage: image, scale: 2).cost >= 400)
    }

    @Test func valueEqualityIsByImageIdentity() throws {
        let a = try #require(TestImage.make(width: 4, height: 4))
        let b = try #require(TestImage.make(width: 4, height: 4))
        #expect(LoadableImageValue(cgImage: a, scale: 1) == LoadableImageValue(cgImage: a, scale: 1))
        #expect(LoadableImageValue(cgImage: a, scale: 1) != LoadableImageValue(cgImage: b, scale: 1))
    }
}
