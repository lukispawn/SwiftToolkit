/// A `LoadableValueSource` that produces images for a `LoadableImageKey`.
public protocol LoadableImageSource: LoadableValueSource where Value == LoadableImageValue, Query: LoadableImageKey {}

public enum LoadableImageError: Error, Equatable, Sendable {
    case missingKey
    case badStatus(Int)
    case undecodable
}
