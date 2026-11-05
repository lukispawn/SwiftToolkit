#if canImport(MapKit)
import CoreGraphics
import MapKit
import SwiftUI

/// Identity of a place: coordinate and extent, without size or appearance.
public struct MapSnapshotContent: Hashable, Sendable {
    public let latitudeE5: Int
    public let longitudeE5: Int
    public let extentMeters: Int
}

/// Request for a map image around a coordinate.
///
/// Coordinates are rounded to 5 decimal places (about 1 m) and the frame up to multiples of
/// 64 pt, so tiny changes do not trigger new snapshots.
public struct MapSnapshotKey: LoadableImageKey {
    public let latitudeE5: Int
    public let longitudeE5: Int
    /// Visible extent in meters, used as the latitudinal and longitudinal span of the region.
    public let extentMeters: Int
    public let isDark: Bool
    public let scale: CGFloat
    public let width: Int
    public let height: Int

    public init(
        latitude: Double, longitude: Double, extentMeters: Int = 3000,
        colorScheme: ColorScheme, displayScale: CGFloat, size: CGSize
    ) {
        latitudeE5 = Int((latitude * 100_000).rounded())
        longitudeE5 = Int((longitude * 100_000).rounded())
        self.extentMeters = extentMeters
        isDark = colorScheme == .dark
        scale = displayScale
        let rounded = LoadableImageSize.rounded(size)
        width = Int(rounded.width)
        height = Int(rounded.height)
    }

    public var contentID: MapSnapshotContent {
        MapSnapshotContent(latitudeE5: latitudeE5, longitudeE5: longitudeE5, extentMeters: extentMeters)
    }
}

/// Renders a map with `MKMapSnapshotter`, without points of interest, in the key's appearance.
public struct MapSnapshotSource: LoadableImageSource {
    public typealias Query = MapSnapshotKey

    public init() {}

    public func fetch(query: MapSnapshotKey?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        let job = await SnapshotJob(query: query)
        let image = try await withTaskCancellationHandler {
            try await job.run()
        } onCancel: {
            Task { await job.cancel() }
        }
        return LoadableImageValue(cgImage: image, scale: query.scale)
    }
}

/// Owns the non-`Sendable` snapshotter on the main actor. Only creating and starting the snapshot
/// happens there; the render itself is asynchronous and does not block the main actor.
@MainActor
private final class SnapshotJob {
    private let snapshotter: MKMapSnapshotter
    private var isCancelled = false

    init(query: MapSnapshotKey) {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: Double(query.latitudeE5) / 100_000, longitude: Double(query.longitudeE5) / 100_000),
            latitudinalMeters: CLLocationDistance(query.extentMeters),
            longitudinalMeters: CLLocationDistance(query.extentMeters))
        options.size = CGSize(width: query.width, height: query.height)
        options.pointOfInterestFilter = .excludingAll
        #if os(iOS)
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: query.isDark ? .dark : .light),
            UITraitCollection(displayScale: query.scale),
        ])
        #elseif os(macOS)
        options.appearance = NSAppearance(named: query.isDark ? .darkAqua : .aqua)
        #endif
        snapshotter = MKMapSnapshotter(options: options)
    }

    func cancel() {
        isCancelled = true
        snapshotter.cancel()
    }

    func run() async throws -> CGImage {
        // A cancel that arrived before start() would otherwise be lost and the snapshot rendered anyway.
        try Task.checkCancellation()
        guard !isCancelled else { throw CancellationError() }
        let snapshot = try await snapshotter.start()
        #if os(iOS)
        guard let image = snapshot.image.cgImage else { throw LoadableImageError.undecodable }
        #elseif os(macOS)
        guard let image = snapshot.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw LoadableImageError.undecodable }
        #endif
        return image
    }
}
#endif
