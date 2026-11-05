import CoreGraphics
import Foundation
import ImageIO

/// Request for an image at `url`, decoded no larger than the (rounded) frame it is shown in.
public struct ImageURLKey: LoadableImageKey {
    public let url: URL
    /// Frame size in points, rounded up to a multiple of 64 so nearby sizes share one load.
    public let pointSize: CGSize
    public let scale: CGFloat

    public init(url: URL, size: CGSize, scale: CGFloat) {
        self.url = url
        pointSize = LoadableImageSize.rounded(size)
        self.scale = scale
    }

    public var pixelSize: CGSize {
        CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
    }

    public var contentID: URL { url }
}

/// Loads local (`file://`) and remote (`http(s)://`) images with `URLSession` and decodes them with
/// ImageIO, downscaled to the key's pixel size. Never upscales.
public struct ImageURLSource: LoadableImageSource {
    public typealias Query = ImageURLKey
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(query: ImageURLKey?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        let (data, response) = try await session.data(from: query.url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LoadableImageError.badStatus(http.statusCode)
        }
        try Task.checkCancellation()
        guard let image = Self.decode(data, frame: query.pixelSize) else {
            throw LoadableImageError.undecodable
        }
        return LoadableImageValue(cgImage: image, scale: query.scale)
    }

    private static func decode(_ data: Data, frame: CGSize) -> CGImage? {
        let maxPixel = max(frame.width, frame.height)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0
        else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let longest = max(width, height)
        // The limit applies to the longest side, so size it for filling the frame, not fitting it.
        var limit = maxPixel
        if longest > 0, frame.width > 0, frame.height > 0 {
            let fill = max(frame.width / width, frame.height / height)
            limit = min(longest * fill, longest)
        }
        if limit > 0 { options[kCGImageSourceThumbnailMaxPixelSize] = limit.rounded(.up) }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
