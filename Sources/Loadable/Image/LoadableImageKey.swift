/// Identifies one rendition of an image. `contentID` identifies the content without
/// size or appearance, so a view can keep the previous image while a new rendition of
/// the same content loads, and replace it at once when the content changes.
public protocol LoadableImageKey: Hashable, Sendable {
    associatedtype ContentID: Hashable & Sendable
    var contentID: ContentID { get }
}
