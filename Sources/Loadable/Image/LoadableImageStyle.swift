import SwiftUI

/// How a `LoadableImage` presents its loaded image. Apply with `.loadableImageStyle(.fit)`.
public struct LoadableImageStyle: Equatable, Sendable {
    public var contentMode: ContentMode
    public var fadeDuration: Double

    public init(contentMode: ContentMode, fadeDuration: Double = 0.25) {
        self.contentMode = contentMode
        self.fadeDuration = fadeDuration
    }

    /// Fills the frame and crops the overflow.
    public static let automatic = LoadableImageStyle(contentMode: .fill)
    /// Fits the whole image inside the frame.
    public static let fit = LoadableImageStyle(contentMode: .fit)
}

extension EnvironmentValues {
    @Entry var loadableImageStyle: LoadableImageStyle = .automatic
}

public extension View {
    func loadableImageStyle(_ style: LoadableImageStyle) -> some View {
        environment(\.loadableImageStyle, style)
    }
}

/// Pure rules behind the view, kept separate so they can be tested without rendering.
enum LoadableImageLayout {
    static func key<Query>(
        size: CGSize, colorScheme: ColorScheme, displayScale: CGFloat,
        provider: (CGSize, ColorScheme, CGFloat) -> Query?
    ) -> Query? {
        guard size.width > 0, size.height > 0 else { return nil }
        return provider(size, colorScheme, displayScale)
    }

    enum Presentation: Equatable { case image, failure, placeholder }

    /// An image that is still visible wins over an error, as in the view.
    static func presentation(hasImage: Bool, hasError: Bool) -> Presentation {
        if hasImage { return .image }
        return hasError ? .failure : .placeholder
    }

    /// The overlay belongs to the loaded image only, never to the placeholder or failure view.
    static func showsOverlay(for presentation: Presentation) -> Bool { presentation == .image }

    static func animation(reduceMotion: Bool, style: LoadableImageStyle) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: style.fadeDuration)
    }

    /// Decorative images are hidden; a failure view holds a retry action and must stay reachable.
    static func isAccessibilityHidden(label: LocalizedStringKey?, isFailure: Bool = false) -> Bool {
        !isFailure && label == nil
    }
}
