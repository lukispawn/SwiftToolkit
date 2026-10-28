import SwiftUI

extension LoadableUI.Components {
    public struct Loading: View {
        public init() {}
        public var body: some View { ProgressView("Loading…").padding() }
    }
}
