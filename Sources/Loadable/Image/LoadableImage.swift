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
public struct LoadableImage<Source: LoadableImageSource, Placeholder: View, Failure: View>: View {
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

    public init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping (_ retry: @escaping () -> Void) -> Failure
    ) {
        _model = State(initialValue: LoadableImageModel(source: source))
        self.accessibilityLabel = accessibilityLabel
        self.key = key
        self.placeholder = placeholder
        self.failure = failure
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
            .accessibilityHidden(LoadableImageLayout.isAccessibilityHidden(label: accessibilityLabel))
            .modifier(OptionalLabel(label: accessibilityLabel))
    }

    @ViewBuilder
    private var content: some View {
        if let image = model.image {
            Image(decorative: image.cgImage, scale: image.scale)
                .resizable()
                .aspectRatio(contentMode: style.contentMode)
                .transition(.opacity)
        } else if model.error != nil {
            failure { Task { await model.retry() } }
        } else {
            placeholder()
        }
    }
}

private struct OptionalLabel: ViewModifier {
    let label: LocalizedStringKey?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            content
        }
    }
}

public extension LoadableImage where Placeholder == LoadableImagePlaceholder, Failure == LoadableImagePlaceholder {
    /// Gray backing for loading and failure; use the full initializer for custom states.
    init(
        source: Source,
        accessibilityLabel: LocalizedStringKey? = nil,
        key: @escaping (CGSize, ColorScheme, CGFloat) -> Source.Query?
    ) {
        self.init(
            source: source, accessibilityLabel: accessibilityLabel, key: key,
            placeholder: { LoadableImagePlaceholder() }, failure: { _ in LoadableImagePlaceholder() })
    }
}
