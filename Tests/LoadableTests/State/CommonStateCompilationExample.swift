// A consumer can aggregate heterogeneous stores using only public API.
import Loadable
import Observation
import SwiftUI

@MainActor @Observable
private final class CommonStateExampleModel: LoadableStateProviding {
    let valueStore = LoadableValueStore(constant: String?.none)
    let collectionStore = LoadableCollectionStore(items: [Row]())

    var loadableState: LoadableState {
        .merge(stores: [valueStore, collectionStore])
    }
}

private struct CommonStateExampleView: View {
    @State private var model = CommonStateExampleModel()

    var body: some View {
        let state = model.loadableState
        switch state.phase {
        case .loaded:
            Text("All required data is available")
                .overlay(alignment: .trailing) {
                    if state.isLoading { ProgressView() }
                }
        case .loading: ProgressView()
        case .idle: Text("Waiting")
        case .failed:
            Text(state.blockingFailures.first?.error.localizedDescription ?? "Could not load data")
        }
    }
}
