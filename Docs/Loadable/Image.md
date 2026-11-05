# LoadableImage

`LoadableImage` is an `AsyncImage` counterpart built on `Loadable`. It adds an in-memory cache,
one shared load per key, a limit on concurrent loads, and keeps the previous image while a new
rendition of the same content loads. It ships in the `Loadable` product (SwiftToolkit 1.9.0+).

| Need | Use |
| --- | --- |
| A photo from a local or remote URL | `ImageURLSource` + `ImageURLKey` |
| A frame from a video URL | `VideoThumbnailSource` + `VideoThumbnailKey` |
| A map around a coordinate | `MapSnapshotSource` + `MapSnapshotKey` |
| Anything else | your own `LoadableImageSource` + `LoadableImageKey` |
| Caching and shared loading | wrap any source in `CachedImageSource` |

## Quick start

```swift
import Loadable
import SwiftUI

struct PhotoTile: View {
    let url: URL

    var body: some View {
        LoadableImage(
            source: CachedImageSource(ImageURLSource()),
            key: { size, _, scale in ImageURLKey(url: url, size: size, scale: scale) }
        )
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 12))
    }
}
```

The view measures its own frame and passes it, with the color scheme and display scale, to `key`.
Return `nil` for "no image": the placeholder shows and nothing loads. Corner radius and aspect
ratio belong to the parent. Without custom builders the placeholder and the failure state are a
neutral gray (`LoadableImagePlaceholder`). Use the long initializer for your own:

```swift
LoadableImage(
    source: source, accessibilityLabel: "Photo",
    key: { size, _, scale in ImageURLKey(url: url, size: size, scale: scale) },
    placeholder: { ProgressView() },
    failure: { retry in Button("Retry", action: retry) })
```

The source is fixed for the lifetime of the view; attach `.id(_:)` to replace it. Images are
decorative by default (hidden from VoiceOver); pass `accessibilityLabel` to expose one. The
failure view is never hidden, so its retry action stays reachable.
`.loadableImageStyle(.fit)` shows the whole image instead of filling the frame.

## Keys: content versus rendition

A key identifies one rendition of an image. Its `contentID` identifies the content alone,
without size or appearance:

- Same `contentID`, different key (the frame was resized, dark mode toggled): the view waits
  150 ms (set it with the `debounce:` parameter), keeps the old image visible, and swaps when the
  new one arrives. A key whose image is already in the cache skips the wait.
- Different `contentID` (another URL, another place): the old image is dropped at once and the
  placeholder shows. A view never shows another content's image.
- A size change while the first load is still running waits too, so a window drag does not start
  a load per step. The very first load never waits.

Round sizes inside your key so small resizes do not reload. `LoadableImageSize.rounded(_:)`
rounds each dimension up to a multiple of 64 pt; the built-in keys already do this.
Custom sources are responsible for their own rounding: an unrounded size reloads on every frame of a
window drag (the 150 ms wait softens this but does not remove it).

## Cache and concurrency

`CachedImageSource(base, cache: .shared, namespace:)` provides:

- one load per `(namespace, key)`; concurrent requests wait for the same load, and the load is
  cancelled only when every waiter has cancelled;
- at most 2 loads at a time per `LoadableImageCache` (set `maxConcurrentLoads`), queued FIFO; a
  cancelled load frees its slot;
- an `NSCache` limit in bytes (64 MB on iOS, 256 MB on macOS by default), which the system may
  also purge under memory pressure;
- errors and cancellations are never cached.

Sources that share a cache need different `namespace`s unless their keys mean the same image
(the default namespace is the source type). Memory only: nothing is written to disk.

## Maps

`MapSnapshotSource` is a ready-to-use example. Active Regions or another app can write a tailored
source on the same protocol instead.

```swift
struct PlaceMap: View {
    let latitude: Double
    let longitude: Double

    var body: some View {
        LoadableImage(
            source: CachedImageSource(MapSnapshotSource()),
            key: { size, scheme, scale in
                MapSnapshotKey(
                    latitude: latitude, longitude: longitude, extentMeters: 3000,
                    colorScheme: scheme, displayScale: scale, size: size)
            },
            placeholder: { LoadableImagePlaceholder() },
            failure: { _ in LoadableImagePlaceholder() })
        .overlay { Image(systemName: "mappin.circle.fill").font(.title).foregroundStyle(.red) }
    }
}
```

The key rounds coordinates to 5 decimal places (about 1 m) and the frame up to multiples of
64 pt; its `contentID` is the coordinate plus extent. The source uses `MKMapSnapshotter` without
points of interest, in the key's light or dark appearance, and touches the main actor only to
create and start the snapshot.

## Writing your own source

```swift
struct AvatarKey: LoadableImageKey {
    let userID: String
    let pixelWidth: Int
    var contentID: String { userID }
}

struct AvatarSource: LoadableImageSource {
    typealias Query = AvatarKey

    func fetch(query: AvatarKey?) async throws -> LoadableImageValue {
        guard let query else { throw LoadableImageError.missingKey }
        // Fetch and decode off the main actor, then:
        // return LoadableImageValue(cgImage: image, scale: 2)
        throw LoadableImageError.undecodable
    }
}
```

A source may also implement `cachedValue(for:)` (`CachedImageSource` does) so a reappearing view
shows a cached image without waiting. A source is `Sendable` (an actor or a value type), returns a `CGImage` with its scale, never
touches the view, and checks cancellation in long work.

## Previews and tests

`StaticImageSource`, `DelayedImageSource`, `FailingImageSource` and `CountingImageSource` need no
network. The `Image` page of `LoadablePreviewGallery` shows the loading, loaded and failed states,
key changes and a grid of twelve. Interactive previews on an iOS simulator show the loaded states;
a static macOS snapshot is taken before any load completes.
