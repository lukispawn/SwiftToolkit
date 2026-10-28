#if DEBUG
import SwiftUI

/// Frozen states use the same presentation as the live demos, without fake sleeping tasks.
private struct CollectionSnapshotPreview: View {
    typealias Source = LoadableCollection.OperationSource<DemoItem, Never, Never, any Error>
    @State private var store: LoadableCollectionStore<Source>

    init(items: [DemoItem] = [], phase: LoadableCollection.Phase<any Error> = .idle,
         hasLoaded: Bool? = nil) {
        _store = State(initialValue: .init(items: items, phase: phase, hasLoaded: hasLoaded))
    }

    var body: some View {
        NavigationStack {
            DemoResults(store: store)
                .navigationTitle("Frozen snapshot")
        }
        .tint(.indigo)
    }
}

private let snapshotPeople = [
    DemoItem(id: "1", title: "Alice Smith", subtitle: "Member ID 1000001"),
    DemoItem(id: "2", title: "James Johnson", subtitle: "Member ID 1000002"),
    DemoItem(id: "3", title: "Catherine Wilson", subtitle: "Member ID 1000003")
]

#Preview("Snapshot · loaded list") {
    CollectionSnapshotPreview(items: snapshotPeople).demoPreviewSize(width: 420, height: 600)
}
#Preview("Snapshot · loading") {
    CollectionSnapshotPreview(phase: .loading).demoPreviewSize(width: 420, height: 600)
}
#Preview("Snapshot · empty") {
    CollectionSnapshotPreview(hasLoaded: true).demoPreviewSize(width: 420, height: 600)
}
#Preview("Snapshot · first-load error") {
    CollectionSnapshotPreview(phase: .failed(DemoFailure.noConnection))
        .demoPreviewSize(width: 420, height: 600)
}
#Preview("Snapshot · page error with retained items") {
    CollectionSnapshotPreview(items: snapshotPeople,
        phase: .failed(DemoFailure.timeout, operation: .page(.next)))
        .demoPreviewSize(width: 420, height: 650)
}
#Preview("Profile · loaded value") {
    DemoProfileCard(profile: DemoProfile(revision: 3)).padding(24).demoPreviewSize(width: 440)
}
#endif
