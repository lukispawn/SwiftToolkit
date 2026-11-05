/// Adds caching, shared loading and a concurrency limit to any image source.
///
/// Sources that share a cache must use distinct `namespace`s unless their keys mean the same image.
public struct CachedImageSource<Base: LoadableImageSource>: LoadableImageSource {
    public typealias Query = Base.Query
    private let base: Base
    private let cache: LoadableImageCache
    private let namespace: String

    public init(
        _ base: Base,
        cache: LoadableImageCache = .shared,
        namespace: String = String(reflecting: Base.self)
    ) {
        self.base = base
        self.cache = cache
        self.namespace = namespace
    }

    public func fetch(query: Base.Query?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        let base = base
        return try await cache.image(for: query, namespace: namespace) {
            try await base.fetch(query: query)
        }
    }
}
