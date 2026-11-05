import CoreGraphics

/// A decoded image ready for display, with the scale it was rendered for.
public struct LoadableImageValue: @unchecked Sendable, Equatable {
    // Safety: CGImage is immutable once created, so sharing it across isolation domains is safe.
    public let cgImage: CGImage
    public let scale: CGFloat

    public init(cgImage: CGImage, scale: CGFloat) {
        self.cgImage = cgImage
        self.scale = scale
    }

    /// Approximate memory footprint in bytes, used as the cache cost.
    public var cost: Int { cgImage.bytesPerRow * cgImage.height }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.cgImage === rhs.cgImage && lhs.scale == rhs.scale
    }
}
