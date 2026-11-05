import CoreGraphics
import Foundation

#if canImport(AVFoundation)
import AVFoundation

/// Request for one frame of the video at `url`.
public struct VideoThumbnailKey: LoadableImageKey {
    public let url: URL
    public let timeMilliseconds: Int
    /// Frame size in points, rounded up to a multiple of 64 so nearby sizes share one load.
    public let pointSize: CGSize
    public let scale: CGFloat

    public init(url: URL, time: Duration = .zero, size: CGSize, scale: CGFloat) {
        self.url = url
        let parts = time.components
        timeMilliseconds = Int(parts.seconds) * 1000 + Int(parts.attoseconds / 1_000_000_000_000_000)
        pointSize = LoadableImageSize.rounded(size)
        self.scale = scale
    }

    public var contentID: URL { url }
}

/// Extracts a frame from a local or remote video with `AVAssetImageGenerator`.
public struct VideoThumbnailSource: LoadableImageSource {
    public typealias Query = VideoThumbnailKey

    public init() {}

    public func fetch(query: VideoThumbnailKey?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: query.url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: query.pointSize.width * query.scale, height: query.pointSize.height * query.scale)
        do {
            let (image, _) = try await generator.image(at: CMTime(value: CMTimeValue(query.timeMilliseconds), timescale: 1000))
            return LoadableImageValue(cgImage: image, scale: query.scale)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw LoadableImageError.undecodable
        }
    }
}
#endif
