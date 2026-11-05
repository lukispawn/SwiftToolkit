import SwiftUI
import Testing
@testable import Loadable

@Suite("LoadableImage layout rules", .timeLimit(.minutes(1)))
struct LoadableImageViewTests {
    private let provider: (CGSize, ColorScheme, CGFloat) -> PreviewImageKey? = { size, _, _ in
        PreviewImageKey(contentID: "a", variant: Int(size.width))
    }

    @Test(arguments: [CGSize.zero, CGSize(width: -1, height: 10), CGSize(width: 10, height: 0)])
    func nonPositiveSizeYieldsNilKey(size: CGSize) {
        #expect(LoadableImageLayout.key(size: size, colorScheme: .light, displayScale: 2, provider: provider) == nil)
    }

    @Test func positiveSizeCallsProvider() {
        let key = LoadableImageLayout.key(
            size: CGSize(width: 50, height: 20), colorScheme: .dark, displayScale: 3, provider: provider)
        #expect(key == PreviewImageKey(contentID: "a", variant: 50))
    }

    @Test func reduceMotionDisablesAnimation() {
        #expect(LoadableImageLayout.animation(reduceMotion: true, style: .automatic) == nil)
        #expect(LoadableImageLayout.animation(reduceMotion: false, style: .automatic) != nil)
    }

    @Test func labelNilHidesFromAccessibility() {
        #expect(LoadableImageLayout.isAccessibilityHidden(label: nil))
        #expect(!LoadableImageLayout.isAccessibilityHidden(label: "Map"))
    }

    @Test func stylesDifferByContentMode() {
        #expect(LoadableImageStyle.automatic.contentMode == .fill)
        #expect(LoadableImageStyle.fit.contentMode == .fit)
    }
}
