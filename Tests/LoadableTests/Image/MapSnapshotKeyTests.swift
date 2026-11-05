import SwiftUI
import Testing
@testable import Loadable

@Suite("MapSnapshotKey", .timeLimit(.minutes(1)))
struct MapSnapshotKeyTests {
    private func key(
        lat: Double = 49.3, lon: Double = 22.6, extent: Int = 3000,
        scheme: ColorScheme = .light, scale: CGFloat = 2, size: CGSize = CGSize(width: 100, height: 100)
    ) -> MapSnapshotKey {
        MapSnapshotKey(
            latitude: lat, longitude: lon, extentMeters: extent, colorScheme: scheme, displayScale: scale, size: size)
    }

    @Test func coordinatesRoundedTo5Places() {
        #expect(key(lat: 49.30000004) == key(lat: 49.299999999))
        #expect(key(lat: 49.30001) != key(lat: 49.3))
        #expect(key(lat: 49.3).latitudeE5 == 4_930_000)
    }

    @Test func sizeRoundedUpTo64() {
        #expect(key(size: CGSize(width: 65, height: 1)).width == 128)
        #expect(key(size: CGSize(width: 65, height: 1)).height == 64)
        #expect(key(size: CGSize(width: 70, height: 100)) == key(size: CGSize(width: 120, height: 128)))
    }

    @Test func contentIDIgnoresSizeAndScheme() {
        let a = key(scheme: .light, size: CGSize(width: 100, height: 100))
        let b = key(scheme: .dark, size: CGSize(width: 500, height: 300))
        #expect(a.contentID == b.contentID)
    }

    @Test func contentIDChangesWithCoordinateOrExtent() {
        #expect(key().contentID != key(lat: 49.4).contentID)
        #expect(key().contentID != key(lon: 22.7).contentID)
        #expect(key().contentID != key(extent: 1000).contentID)
    }

    @Test func schemeAndScaleAffectKey() {
        #expect(key(scheme: .light) != key(scheme: .dark))
        #expect(key(scale: 2) != key(scale: 3))
        #expect(key(scale: 2).scale == 2)
    }

    @Test func nilKeyThrowsMissingKey() async {
        await #expect(throws: LoadableImageError.missingKey) { try await MapSnapshotSource().fetch(query: nil) }
    }

    @Test func preCancelledFetchThrowsCancellationWithoutRendering() async {
        let task = Task {
            try await MapSnapshotSource().fetch(query: key(size: CGSize(width: 64, height: 64)))
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
