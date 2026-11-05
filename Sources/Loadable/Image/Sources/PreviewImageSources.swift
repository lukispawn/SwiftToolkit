import CoreGraphics

/// Key used by the preview and test sources.
public struct PreviewImageKey: LoadableImageKey {
    public var contentID: String
    public var variant: Int

    public init(contentID: String, variant: Int = 0) {
        self.contentID = contentID
        self.variant = variant
    }
}

public enum PreviewImageError: Error, Sendable {
    case failed
}

/// Returns a flat gray image. Needs no network, so previews and tests stay deterministic.
public struct StaticImageSource: LoadableImageSource {
    public typealias Query = PreviewImageKey
    private let gray: CGFloat
    private let size: CGSize

    public init(gray: CGFloat, size: CGSize) {
        self.gray = gray
        self.size = size
    }

    public func fetch(query: PreviewImageKey?) async throws -> LoadableImageValue {
        guard query != nil else { throw LoadableImageError.missingKey }
        try Task.checkCancellation()
        guard let context = CGContext(
            data: nil, width: max(1, Int(size.width)), height: max(1, Int(size.height)),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw LoadableImageError.undecodable }
        context.setFillColor(gray: gray, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else { throw LoadableImageError.undecodable }
        return LoadableImageValue(cgImage: image, scale: 1)
    }
}

/// Delays another source by `delay`; cancellation interrupts the wait.
public struct DelayedImageSource<Base: LoadableImageSource>: LoadableImageSource {
    public typealias Query = Base.Query
    private let base: Base
    private let delay: Duration

    public init(base: Base, delay: Duration) {
        self.base = base
        self.delay = delay
    }

    public func fetch(query: Base.Query?) async throws -> LoadableImageValue {
        try await Task.sleep(for: delay)
        return try await base.fetch(query: query)
    }
}

/// Always fails with `error`.
public struct FailingImageSource: LoadableImageSource {
    public typealias Query = PreviewImageKey
    private let error: any Error & Sendable

    public init(error: any Error & Sendable = PreviewImageError.failed) {
        self.error = error
    }

    public func fetch(query: PreviewImageKey?) async throws -> LoadableImageValue {
        throw error
    }
}

/// Wraps a source and records how often and how concurrently it was called.
public actor CountingImageSource<Base: LoadableImageSource>: LoadableImageSource {
    public typealias Query = Base.Query
    private let base: Base
    public private(set) var fetchCount = 0
    public private(set) var maxConcurrent = 0
    private var active = 0

    public init(_ base: Base) { self.base = base }

    public func fetch(query: Base.Query?) async throws -> LoadableImageValue {
        fetchCount += 1
        active += 1
        maxConcurrent = max(maxConcurrent, active)
        defer { active -= 1 }
        return try await base.fetch(query: query)
    }
}
