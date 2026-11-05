/// A `LoadableValueSource` that produces images for a `LoadableImageKey`.
public protocol LoadableImageSource: LoadableValueSource where Value == LoadableImageValue, Query: LoadableImageKey {
    /// A value that can be shown right now without loading, or `nil`. Sources backed by a cache
    /// return it here so a view that reappears shows the image in its first frame.
    func cachedValue(for query: Query) -> LoadableImageValue?
}

public extension LoadableImageSource {
    func cachedValue(for query: Query) -> LoadableImageValue? { nil }
}

public enum LoadableImageError: Error, Equatable, Sendable {
    case missingKey
    case badStatus(Int)
    case undecodable
}
