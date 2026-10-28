import SwiftUI

extension LoadableUI.Components {
    public struct Failure<FailureValue: Error>: View {
        private let context: LoadableUI.FailureContext<FailureValue>
        public init(context: LoadableUI.FailureContext<FailureValue>) { self.context = context }

        public var body: some View {
            VStack(spacing: 12) {
                Label("Could not load data", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text(context.error.localizedDescription).font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let retry = context.retry { Button("Retry", action: retry).buttonStyle(.bordered) }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}
