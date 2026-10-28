@MainActor
final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    init(_ value: Object?) { self.value = value }
}
