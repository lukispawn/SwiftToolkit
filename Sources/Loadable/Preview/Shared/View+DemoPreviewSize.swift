#if DEBUG
import SwiftUI

extension View {
    /// macOS previews need an initial window size. iPhone/iPad use the canvas device.
    @ViewBuilder
    func demoPreviewSize(width: CGFloat, height: CGFloat? = nil) -> some View {
        #if os(macOS)
        frame(width: width, height: height)
        #else
        self
        #endif
    }
}
#endif
