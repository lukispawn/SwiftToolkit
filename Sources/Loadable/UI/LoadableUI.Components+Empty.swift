import SwiftUI

extension LoadableUI.Components {
    public struct Empty: View {
        public init() {}
        public var body: some View {
            ContentUnavailableView("No results", systemImage: "tray")
        }
    }
}
