import SwiftUI

extension LoadableUI.Components {
    public struct Idle: View {
        public init() {}
        public var body: some View {
            ContentUnavailableView("Ready to load", systemImage: "arrow.down.circle")
        }
    }
}
