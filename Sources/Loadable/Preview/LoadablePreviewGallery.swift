#if DEBUG
import SwiftUI

/// Open this file's Canvas for the interactive gallery. All demos are DEBUG-only.
public struct LoadablePreviewGallery: View {
    public enum Example: String, CaseIterable, Identifiable {
        case value = "Value"
        case collection = "List"
        case search = "Search"
        case singlePage = "All items"
        case layouts = "Layouts"
        case state = "Merged state"
        case chat = "Chat"
        public var id: String { rawValue }
    }
    @State private var selected: Example

    public init(example: Example = .collection) {
        _selected = State(initialValue: example)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                examplePicker.pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
                examplePicker.pickerStyle(.menu)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Group {
                switch selected {
                case .value: LoadableValueDemoView()
                case .collection: LoadableCollectionBasicDemoView()
                case .search: LoadableCollectionSearchDemoView()
                case .singlePage: LoadableCollectionSinglePageDemoView()
                case .layouts: LoadableCollectionLayoutDemoView(layout: .cards)
                case .state: LoadableStateDemoView()
                case .chat: LoadableChat.LoadableView()
                }
            }
        }
        .tint(.indigo)
    }

    private var examplePicker: some View {
        Picker("Example", selection: $selected) {
            ForEach(Example.allCases) { Text($0.rawValue).tag($0) }
        }
    }
}

#Preview("Loadable · gallery") { LoadablePreviewGallery().demoPreviewSize(width: 440, height: 840) }
#Preview("Loadable · dark appearance") {
    LoadablePreviewGallery().preferredColorScheme(.dark).demoPreviewSize(width: 440, height: 840)
}
#Preview("Loadable · larger text") {
    LoadablePreviewGallery().environment(\.dynamicTypeSize, .accessibility1).demoPreviewSize(width: 440, height: 900)
}
#Preview("Loadable · collection layouts") {
    LoadablePreviewGallery(example: .layouts).demoPreviewSize(width: 440, height: 840)
}
#Preview("Loadable · searchable list") {
    LoadablePreviewGallery(example: .search).demoPreviewSize(width: 440, height: 840)
}
#Preview("Loadable · merged store states") {
    LoadablePreviewGallery(example: .state).demoPreviewSize(width: 480, height: 900)
}
#Preview("Loadable · chat") {
    LoadablePreviewGallery(example: .chat).demoPreviewSize(width: 460, height: 900)
}
#endif
