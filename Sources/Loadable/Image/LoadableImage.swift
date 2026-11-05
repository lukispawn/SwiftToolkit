import SwiftUI

/// Neutral gray backing used while loading and when no image is requested.
public struct LoadableImagePlaceholder: View {
    public init() {}
    public var body: some View { Rectangle().fill(.fill.tertiary) }
}

/// An `AsyncImage` counterpart built on `Loadable`: cached, shared loads, kept-while-reloading images.
///
/// `key` receives the measured frame, color scheme and display scale and returns the request key
/// (or `nil` for "no image"). Round the size inside the key so small resizes do not reload.
/// The source is fixed for the lifetime of the view; use `.id(_:)` to replace it. Corner radius and
/// aspect ratio come from the parent.
///
/// `overlay` is drawn over the loaded image only, in the image's frame. It appears and disappears
/// together with the image (same fade, none under Reduce Motion), stays while an older image is kept
/// during a reload of the same content, and is hidden from VoiceOver exactly like the image unless
/// `accessibilityLabel` is given. It is a `@ViewBuilder` without an `Image` argument (unlike
/// `AsyncImage`'s `content:`), because the image is a decoded `CGImage` that the view sizes itself.
public struct LoadableImage<
    Source: LoadableImageSource, Placeholder: View, Failure: View, Overlay: View
>: View {
    @State private var model: LoadableImageModel<Source>
    @State private var size: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.loadableImageStyle) private var style

    private let key: (CGSize, ColorScheme, CGFloat) -> Source.Query?
    private let accessibilityLabel: LocalizedStringKey?
    private let placeholder: () -> Placeholder
    private let failure: (_ retry: @escaping () -> Void) -> Failure
    private let overlay: () -> Overlay

    public init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        debounce: Duration = .milliseconds(150),
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping (_ retry: @escaping () -> Void) -> Failure,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        _model = State(initialValue: LoadableImageModel(source: source, debounce: debounce))
        self.accessibilityLabel = accessibilityLabel
        self.key = key
        self.placeholder = placeholder
        self.failure = failure
        self.overlay = overlay
    }

    private var currentKey: Source.Query? {
        LoadableImageLayout.key(size: size, colorScheme: colorScheme, displayScale: displayScale, provider: key)
    }

    public var body: some View {
        Color.clear
            .overlay { content }
            .clipped()
            .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
            .task(id: currentKey) { await model.update(key: currentKey) }
            .animation(
                LoadableImageLayout.animation(reduceMotion: reduceMotion, style: style),
                value: model.image.map { ObjectIdentifier($0.cgImage) })
    }

    @ViewBuilder
    private var content: some View {
        let presentation = LoadableImageLayout.presentation(hasImage: model.image != nil, hasError: model.error != nil)
        if let image = model.image {
            // The image may overflow the frame when filling, so the overlay sits on a clipped, exactly
            // sized layer instead of on the image.
            Color.clear
                .overlay {
                    Image(decorative: image.cgImage, scale: image.scale)
                        .resizable()
                        .aspectRatio(contentMode: style.contentMode)
                }
                .clipped()
                .overlay { if LoadableImageLayout.showsOverlay(for: presentation) { overlay() } }
                .transition(.opacity)
                .modifier(ImageAccessibility(label: accessibilityLabel))
        } else if model.error != nil {
            failure { Task { await model.retry() } }
        } else {
            placeholder().modifier(ImageAccessibility(label: accessibilityLabel))
        }
    }
}

/// Applied to the image and placeholder only, never to the failure view.
private struct ImageAccessibility: ViewModifier {
    let label: LocalizedStringKey?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(LoadableImageLayout.isAccessibilityHidden(label: label))
        }
    }
}

public extension LoadableImage where Overlay == EmptyView {
    /// Custom loading and failure states, no overlay.
    init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        debounce: Duration = .milliseconds(150),
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping (_ retry: @escaping () -> Void) -> Failure
    ) {
        self.init(
            source: source, accessibilityLabel: accessibilityLabel, debounce: debounce, key: key,
            placeholder: placeholder, failure: failure, overlay: { EmptyView() })
    }
}

public extension LoadableImage where Placeholder == LoadableImagePlaceholder, Failure == LoadableImagePlaceholder {
    /// Gray backing for loading and failure, with an overlay over the loaded image.
    init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        debounce: Duration = .milliseconds(150),
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            source: source, accessibilityLabel: accessibilityLabel, debounce: debounce, key: key,
            placeholder: { LoadableImagePlaceholder() }, failure: { _ in LoadableImagePlaceholder() },
            overlay: overlay)
    }
}

public extension LoadableImage
where Placeholder == LoadableImagePlaceholder, Failure == LoadableImagePlaceholder, Overlay == EmptyView {
    /// Gray backing for loading and failure; use the full initializer for custom states.
    init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        debounce: Duration = .milliseconds(150),
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?
    ) {
        self.init(
            source: source, accessibilityLabel: accessibilityLabel, debounce: debounce, key: key,
            placeholder: { LoadableImagePlaceholder() }, failure: { _ in LoadableImagePlaceholder() })
    }
}
