import CoreGraphics

public enum LoadableImageSize {
    /// Rounds each dimension up to a multiple of `step`; non-positive values become 0.
    /// Use it when building keys so small resizes do not trigger new loads.
    public static func rounded(_ size: CGSize, upTo step: CGFloat = 64) -> CGSize {
        CGSize(width: roundedUp(size.width, step), height: roundedUp(size.height, step))
    }

    private static func roundedUp(_ value: CGFloat, _ step: CGFloat) -> CGFloat {
        guard value > 0, step > 0 else { return 0 }
        return (value / step).rounded(.up) * step
    }
}
