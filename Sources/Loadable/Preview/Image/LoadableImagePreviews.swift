#if DEBUG
import SwiftUI

/// Deterministic colored image per key (hue from `contentID`, brightness from `variant`).
struct DemoColorSource: LoadableImageSource {
    typealias Query = PreviewImageKey
    var delay: Duration = .milliseconds(500)
    var onLoad: (@Sendable () async -> Void)?

    func fetch(query: PreviewImageKey?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        await onLoad?()
        try await Task.sleep(for: delay)
        let seed = query.contentID.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }
        let hue = Double((seed * 61) % 360) / 360
        let brightness = 0.55 + 0.1 * Double(query.variant % 4)
        func rgb(_ saturation: Double, _ brightness: Double) -> (CGFloat, CGFloat, CGFloat) {
            let resolved = Color(hue: hue, saturation: saturation, brightness: min(brightness, 1))
                .resolve(in: EnvironmentValues())
            return (CGFloat(resolved.red), CGFloat(resolved.green), CGFloat(resolved.blue))
        }
        guard let context = CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw LoadableImageError.undecodable }
        let base = rgb(0.6, brightness)
        context.setFillColor(red: base.0, green: base.1, blue: base.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let accent = rgb(0.3, brightness + 0.3)
        context.setFillColor(red: accent.0, green: accent.1, blue: accent.2, alpha: 1)
        context.fillEllipse(in: CGRect(x: 16, y: 16, width: 32, height: 32))
        guard let image = context.makeImage() else { throw LoadableImageError.undecodable }
        return LoadableImageValue(cgImage: image, scale: 1)
    }
}

@MainActor @Observable
final class DemoLoadCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

/// One tile with the default gray placeholder and a retry button on failure.
struct DemoImageTile<Source: LoadableImageSource>: View where Source.Query == PreviewImageKey {
    let source: Source
    let key: PreviewImageKey?

    var body: some View {
        LoadableImage(
            source: source, accessibilityLabel: "Demo image", key: { _, _, _ in key },
            placeholder: { LoadableImagePlaceholder() },
            failure: { retry in
                ZStack {
                    LoadableImagePlaceholder()
                    Button(action: retry) { Label("Retry", systemImage: "arrow.clockwise") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            })
    }
}

struct LoadableImageStatesDemo: View {
    @State private var cache = LoadableImageCache()

    var body: some View {
        HStack(spacing: 12) {
            tile("Loading", CachedImageSource(DemoColorSource(delay: .seconds(3600)), cache: cache, namespace: "loading"))
            tile("Loaded", CachedImageSource(DemoColorSource(delay: .milliseconds(400)), cache: cache, namespace: "loaded"))
            tile("Failed", CachedImageSource(FailingImageSource(), cache: cache, namespace: "failed"))
        }
    }

    private func tile<S: LoadableImageSource>(_ title: String, _ source: S) -> some View
    where S.Query == PreviewImageKey {
        VStack {
            DemoImageTile(source: source, key: PreviewImageKey(contentID: "forest"))
                .frame(width: 110, height: 110).clipShape(.rect(cornerRadius: 12))
            Text(title).font(.caption)
        }
    }
}

struct LoadableImageKeyChangeDemo: View {
    @State private var cache = LoadableImageCache()
    @State private var content = "forest"
    @State private var variant = 0

    var body: some View {
        VStack(spacing: 12) {
            DemoImageTile(
                source: CachedImageSource(DemoColorSource(delay: .milliseconds(900)), cache: cache),
                key: PreviewImageKey(contentID: content, variant: variant))
                .frame(width: 200, height: 200).clipShape(.rect(cornerRadius: 16))
            HStack {
                Button("Same content, new size") { variant += 1 }
                Button("Other content") { content = content == "forest" ? "ocean" : "forest"; variant = 0 }
            }
            .buttonStyle(.bordered).controlSize(.small)
            Text("Same content keeps the old image until the new one arrives. Other content shows the placeholder at once.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}

struct LoadableImageGridDemo: View {
    @State private var cache = LoadableImageCache()
    @State private var counter = DemoLoadCounter()
    @State private var width = 360.0

    var body: some View {
        let counter = counter
        let source = CachedImageSource(
            DemoColorSource(delay: .milliseconds(300), onLoad: { await counter.increment() }), cache: cache)
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<12, id: \.self) { index in
                    LoadableImage(
                        source: source,
                        key: { size, _, _ in
                            PreviewImageKey(
                                contentID: "tile-\(index)", variant: Int(LoadableImageSize.rounded(size).width) / 64)
                        })
                        .aspectRatio(1, contentMode: .fit).clipShape(.rect(cornerRadius: 10))
                }
            }
            .frame(width: width)
            Slider(value: $width, in: 240...400) { Text("Width") }
            Text("Loads: \(counter.count). Dragging the slider within one 64 pt step must not add loads.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LoadableImageDemoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("States") { LoadableImageStatesDemo() }
                section("Key changes") { LoadableImageKeyChangeDemo() }
                section("Grid of 12") { LoadableImageGridDemo() }
            }
            .padding(16).frame(maxWidth: .infinity)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }
}

#Preview("Image · states") { LoadableImageStatesDemo().padding().demoPreviewSize(width: 440, height: 220) }
#Preview("Image · key changes") { LoadableImageKeyChangeDemo().padding().demoPreviewSize(width: 440, height: 380) }
#Preview("Image · grid of 12") { LoadableImageGridDemo().padding().demoPreviewSize(width: 440, height: 520) }
#Preview("Image · dark") {
    LoadableImageDemoView().preferredColorScheme(.dark).demoPreviewSize(width: 440, height: 840)
}
#Preview("Image · gallery") { LoadablePreviewGallery(example: .image).demoPreviewSize(width: 440, height: 840) }
#endif
