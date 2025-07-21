# SwiftUI Cross-Platform Development Guide

SwiftUI provides a comprehensive framework for building productivity apps that work seamlessly across iOS 18+, iPadOS 18+, and macOS 15+. This guide covers the essential patterns, APIs, and best practices for creating professional cross-platform applications that feel native on each platform while maximizing code reuse.

## Multi-Window Architecture and Scene Management

SwiftUI's Scene-based architecture enables sophisticated multi-window support through **WindowGroup** for scalable document windows and **Window** for unique auxiliary panels. The framework provides comprehensive lifecycle management and state sharing across windows, with platform-specific behaviors that feel native on each device.

### Basic Multi-Window Setup

```swift
@main
struct ProductivityApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        // Primary window group for documents
        WindowGroup {
            DocumentBrowserView()
                .environmentObject(appState)
        }
        
        // Document windows with value-based identification
        WindowGroup("Document", for: Document.ID.self) { $documentId in
            if let documentId = documentId {
                DocumentView(documentId: documentId)
                    .environmentObject(appState)
            }
        }
        
        #if os(macOS)
        // Single-instance inspector window
        Window("Inspector", id: "inspector") {
            InspectorView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        #endif
    }
}
```

### Advanced Window Management

**Window management differs significantly across platforms**. On iOS, multi-window support is limited to iPadOS devices, while macOS provides the most comprehensive capabilities including window levels, custom positioning, and toolbar styles. The new `.defaultWindowPlacement` modifier in iOS 18 and macOS 15 enables precise window positioning:

```swift
WindowGroup("Floating Panel", id: "floating") {
    FloatingPanelView()
}
.windowLevel(.floating)
.defaultWindowPlacement { content, context in
    let displayBounds = context.defaultDisplay.visibleRect
    let size = content.sizeThatFits(.unspecified)
    return WindowPlacement(
        CGPoint(x: displayBounds.midX - (size.width / 2), 
                y: displayBounds.maxY - size.height - 20),
        size: size
    )
}
```

State management across windows requires careful coordination through **ObservableObject** patterns and environment injection. Using a singleton AppState pattern ensures consistent data sharing while @SceneStorage preserves window-specific state across app launches.

## Navigation Patterns and Adaptive Layouts

### NavigationSplitView for Multi-Column Layouts

NavigationSplitView provides the foundation for iPad and Mac productivity apps, offering sophisticated multi-column layouts with platform-specific behaviors.

#### NavigationSplitViewStyle Configuration

**Balanced style** maintains proportional column widths, ensuring all columns remain visible when space permits. This style provides the most consistent behavior across platforms and works reliably on macOS:

```swift
NavigationSplitView {
    ProjectSidebar()
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
} content: {
    TaskList()
        .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
} detail: {
    TaskDetail()
}
.navigationSplitViewStyle(.balanced)
```

**ProminentDetail style** keeps the detail view at full size while overlaying sidebar and content columns. While excellent for content-focused apps on iOS/iPadOS, it lacks proper macOS support and should be avoided for desktop deployments.

**Automatic style** intelligently switches between balanced and prominentDetail based on device and orientation. On iPad, it uses prominentDetail in portrait and balanced in landscape, providing optimal use of available space.

### Adaptive Navigation State Management

Managing navigation state across platform transitions requires sophisticated state handling. This pattern maintains continuity when switching between compact and regular layouts:

```swift
@MainActor
class AdaptiveNavigationStore: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var sidebarSelection: NavigationItem?
    @Published var detailSelection: DetailItem?
    
    private var previousSizeClass: UserInterfaceSizeClass?
    
    func handleSizeClassChange(to newSizeClass: UserInterfaceSizeClass?) {
        guard let previous = previousSizeClass, 
              let new = newSizeClass,
              previous != new else { return }
        
        switch (previous, new) {
        case (.compact, .regular):
            // Transitioning from stack to split view
            transferStackToSplitView()
        case (.regular, .compact):
            // Transitioning from split view to stack
            transferSplitViewToStack()
        default:
            break
        }
        
        previousSizeClass = new
    }
    
    private func transferStackToSplitView() {
        guard !navigationPath.isEmpty else { return }
        
        // Extract selections from navigation path
        var tempPath = navigationPath
        if let firstItem = popFirst(&tempPath) as? NavigationItem {
            sidebarSelection = firstItem
            if let secondItem = popFirst(&tempPath) as? DetailItem {
                detailSelection = secondItem
            }
        }
        
        // Clear navigation path after transfer
        navigationPath = NavigationPath()
    }
    
    private func transferSplitViewToStack() {
        var newPath = NavigationPath()
        
        if let sidebar = sidebarSelection {
            newPath.append(sidebar)
            if let detail = detailSelection {
                newPath.append(detail)
            }
        }
        
        navigationPath = newPath
        sidebarSelection = nil
        detailSelection = nil
    }
}
```

### Platform-Adaptive Layout Patterns

```swift
struct AdaptiveHomeView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad and iPhone landscape
            NavigationSplitView {
                SidebarContent()
                    .listStyle(.sidebar)
            } detail: {
                DetailContent()
            }
        } else {
            // iPhone portrait
            NavigationStack {
                HomeContent()
                    .listStyle(.insetGrouped)
            }
        }
    }
}
```

## Platform-Adaptive UI Patterns

### FormStyle: Platform-Aware Forms

SwiftUI's FormStyle system provides three distinct approaches to form rendering, each with specific platform behaviors and use cases.

#### FormStyle Options

**Automatic style (.automatic)** adapts to platform conventions automatically. On iOS and iPadOS, it defaults to grouped styling with characteristic gray backgrounds and white content rows. On macOS, it switches to a two-column layout that feels native to desktop users.

```swift
Form {
    Section("Personal Information") {
        TextField("First Name", text: $firstName)
        TextField("Last Name", text: $lastName)
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
    }
}
.formStyle(.automatic)
```

**Grouped style (.grouped)** enforces iOS-style grouped lists across all platforms. A critical limitation in macOS 15+ restricts content width to 600 points, potentially breaking layouts with wide content.

**Columns style (.columns)** creates a two-column layout with trailing-aligned labels and leading-aligned values. This style works best with LabeledContent:

```swift
Form {
    Section("Device Information") {
        LabeledContent("Model", value: deviceModel)
        LabeledContent("Storage", value: "512 GB")
        LabeledContent("OS Version", value: osVersion)
    }
}
.formStyle(.columns)
```

#### Adaptive Form Styling

```swift
struct AdaptiveFormStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .formStyle(horizontalSizeClass == .regular ? .columns : .grouped)
            #elseif os(macOS)
            .formStyle(.columns)
            .padding()
            #endif
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
    }
}
```

### Sidebar Styling and List Patterns

#### Platform-Specific List Styles

SwiftUI provides six primary list styles with distinct platform behaviors:

- **`.sidebar`**: Best for navigation lists on iPad/Mac with collapsible sections
- **`.insetGrouped`**: Modern iOS default with rounded corners and edge insets
- **`.plain`**: Minimal styling, default on macOS
- **`.bordered`**: macOS 12+ only, supports alternating row backgrounds
- **`.grouped`**: Legacy iOS grouping without insets

```swift
extension View {
    func adaptiveListStyle() -> some View {
        self.modifier(AdaptiveListStyleModifier())
    }
}

struct AdaptiveListStyleModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content.listStyle(horizontalSizeClass == .regular ? .sidebar : .insetGrouped)
        #elseif os(macOS)
        content.listStyle(.sidebar)
        #endif
    }
}
```

#### Sidebar Implementation

```swift
struct SidebarView: View {
    @Binding var selection: NavigationItem?
    
    var body: some View {
        List(selection: $selection) {
            Section("Main") {
                NavigationLink(value: NavigationItem.home) {
                    Label("Home", systemImage: "house")
                }
                NavigationLink(value: NavigationItem.favorites) {
                    Label("Favorites", systemImage: "star")
                }
            }
            
            Section("Categories") {
                ForEach(categories) { category in
                    NavigationLink(value: NavigationItem.category(category)) {
                        Label(category.name, systemImage: category.icon)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("App Name")
    }
}
```

### Navigation Presentations and Modals

SwiftUI's navigation system provides distinct patterns that automatically adapt to platform conventions. **Sheet presentations** behave as bottom sheets on iOS, form sheets on iPadOS, and modal windows on macOS.

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationSizing(.form) // Consistent sizing across platforms
        .presentationDetents([.medium, .large]) // iOS/iPadOS only
        .presentationBackgroundInteraction(.enabled)
}
```

**FullScreenCover is exclusive to iOS and iPadOS**, requiring alternative approaches on macOS:

```swift
extension View {
    func compatibleFullScreen<Content: View>(
        isPresented: Binding<Bool>, 
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        self.sheet(isPresented: isPresented, content: content)
        #else
        self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
```

**Inspector panels** provide platform-appropriate detail views:

```swift
NavigationStack {
    MainContent()
        .inspector(isPresented: $showInspector) {
            InspectorContent()
                .inspectorColumnWidth(min: 200, ideal: 300, max: 400)
        }
}
```

## Modern iOS 18 and macOS 15 Features

### Enhanced TabView with Sidebar Adaptability

The most significant iOS 18 change for navigation is the `.sidebarAdaptable` TabView style, enabling seamless transitions between tab bar and sidebar presentations:

```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
    }
    .customizationID("app.tab.home")
    
    TabSection("Content") {
        Tab("Library", systemImage: "books.vertical") {
            LibraryView()
        }
        Tab("Downloads", systemImage: "arrow.down.circle") {
            DownloadsView()
        }
    }
}
.tabViewStyle(.sidebarAdaptable)
.tabViewCustomization($customization)
```

### @Entry Macro for Environment Values

The **@Entry macro** simplifies environment and focus value declarations:

```swift
extension EnvironmentValues {
    @Entry var customTheme: Theme = .default
}

extension FocusValues {
    @Entry var customFocusState: Bool = false
}
```

### Enhanced ScrollView APIs

**Enhanced ScrollView APIs** provide precise control over scroll position and visibility:

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
                .onScrollVisibilityChange(threshold: 0.5) { visible in
                    // React to visibility changes
                }
        }
    }
}
.scrollPosition($scrollPosition)
.onScrollGeometryChange(for: Bool.self) { geometry in
    geometry.contentOffset.y < 0
} action: { wasAtTop, isAtTop in
    // Handle scroll position changes
}
```

### Navigation Transitions

**Zoom navigation transitions** create fluid navigation experiences:

```swift
NavigationLink {
    DetailView(item: item)
        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
} label: {
    ItemThumbnail(item: item)
}
.matchedTransitionSource(id: item.id, in: namespace)
```

## Keyboard Shortcuts and Menu Systems

SwiftUI's keyboard shortcut system provides a unified API that works across all platforms, with **CommandMenu** and **CommandGroup** offering deep macOS menu bar integration.

```swift
@main
struct ProductivityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Edit") {
                Button("Copy") { }
                    .keyboardShortcut("c")
                
                Button("Paste") { }
                    .keyboardShortcut("v")
                
                Divider()
                
                Button("Find...") { }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .newItem) {
                Button("New from Template") { }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
```

**MenuBarExtra** on macOS enables status bar applications:

```swift
MenuBarExtra("Task Manager", systemImage: "checkmark.circle") {
    VStack(alignment: .leading) {
        Text("Current Task: \(currentTask)")
            .font(.headline)
        
        Toggle("Notifications", isOn: $isEnabled)
            .keyboardShortcut("n")
        
        Divider()
        
        Button("New Task") { }
            .keyboardShortcut("t", modifiers: [.command, .shift])
    }
    .frame(width: 200)
}
.menuBarExtraStyle(.window)
```

## Platform-Specific Enhancements

### System Materials and Adaptive Styling

Achieving a native look requires strategic use of platform-specific modifiers and adaptive layouts:

```swift
VStack {
    Text("Native Content")
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: platformCornerRadius))
}

private var platformCornerRadius: CGFloat {
    #if os(iOS)
    return 16
    #elseif os(macOS)
    return 8
    #endif
}
```

### Platform-Specific Control Styles

```swift
TextField("Title", text: $title)
    #if os(iOS)
    .textFieldStyle(.roundedBorder)
    #elseif os(macOS)
    .textFieldStyle(.plain)
    #endif

Toggle("Enable", isOn: $isEnabled)
    #if os(iOS)
    .toggleStyle(.switch)
    #elseif os(macOS)
    .toggleStyle(.checkbox)
    #endif
```

### Adaptive Spacing and Layout

```swift
struct AdaptiveSpacing: View {
    var body: some View {
        VStack(spacing: platformSpacing) {
            // Content
        }
        .padding(platformPadding)
    }
    
    private var platformSpacing: CGFloat {
        #if os(iOS)
        return 16
        #elseif os(macOS)
        return 12
        #endif
    }
}
```

## Production-Ready Patterns

### MVVM Architecture with Platform Awareness

```swift
@MainActor
protocol ProductivityViewModel: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func send(_ action: Action)
}

@MainActor
class TaskListViewModel: ProductivityViewModel {
    struct State {
        var tasks: [Task] = []
        var filter: TaskFilter = .all
        var sortOrder: TaskSortOrder = .dueDate
        var selectedTasks: Set<Task.ID> = []
        var isLoading = false
        var error: Error?
    }
    
    enum Action {
        case loadTasks
        case selectTask(Task.ID)
        case deleteSelected
        case updateFilter(TaskFilter)
        case updateSort(TaskSortOrder)
        case createTask(Task.Draft)
    }
    
    @Published private(set) var state = State()
    private let repository: TaskRepositoryProtocol
    private let platformAdapter: PlatformAdapterProtocol
    
    init(repository: TaskRepositoryProtocol, 
         platformAdapter: PlatformAdapterProtocol) {
        self.repository = repository
        self.platformAdapter = platformAdapter
    }
    
    func send(_ action: Action) {
        switch action {
        case .loadTasks:
            loadTasks()
        case .selectTask(let id):
            toggleSelection(id)
        case .deleteSelected:
            deleteSelectedTasks()
        case .updateFilter(let filter):
            state.filter = filter
            applyFilter()
        case .updateSort(let order):
            state.sortOrder = order
            sortTasks()
        case .createTask(let draft):
            createTask(from: draft)
        }
    }
    
    private func loadTasks() {
        state.isLoading = true
        
        Task {
            do {
                let tasks = try await repository.fetchTasks()
                state.tasks = tasks
                applyFilter()
                sortTasks()
                state.isLoading = false
            } catch {
                state.error = error
                state.isLoading = false
                platformAdapter.showError(error)
            }
        }
    }
}
```

### Semantic Styling System

```swift
enum SemanticStyle {
    case primary, secondary, destructive, disabled
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .accentColor
        case .secondary: return .secondary
        case .destructive: return .red
        case .disabled: return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .primary: 
            return .accentColor.opacity(0.15)
        case .secondary: 
            return Color(uiColor: .secondarySystemBackground)
        case .destructive: 
            return .red.opacity(0.15)
        case .disabled: 
            return .gray.opacity(0.1)
        }
    }
}
```

### Platform-Specific ViewModifiers

```swift
struct PlatformAdaptiveContainer: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundColor)
    }
    
    private var maxWidth: CGFloat? {
        #if os(iOS)
        return horizontalSizeClass == .compact ? nil : 700
        #elseif os(macOS)
        return nil
        #endif
    }
    
    private var horizontalPadding: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 16 : 24
        #elseif os(macOS)
        return 20
        #endif
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
```

## Data Management and Document Handling

### Searchable Lists with Filtering

```swift
NavigationStack {
    List(filteredItems) { item in
        DataItemRow(item: item)
    }
    .searchable(text: $searchText, prompt: "Search items...")
    .searchScopes($searchScope) {
        ForEach(SearchScope.allCases, id: \.self) { scope in
            Text(scope.rawValue.capitalized)
        }
    }
}
```

### Document-Based Applications

```swift
struct MyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.myDocumentType] }
    
    var content: DocumentContent
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = try JSONDecoder().decode(DocumentContent.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(content)
        return FileWrapper(regularFileWithContents: data)
    }
}
```

### Form Validation

```swift
Form {
    Section("Personal Information") {
        TextField("Name", text: $name)
            .textInputAutocapitalization(.words)
        
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
    }
}
.toolbar {
    Button("Save") {
        saveItem()
    }
    .disabled(!isFormValid)
}

private var isFormValid: Bool {
    !name.isEmpty && email.contains("@")
}
```

## AVFoundation Integration

### Custom Video Players

```swift
struct CustomVideoPlayer: UIViewRepresentable {
    @ObservedObject var playerVM: PlayerViewModel
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = playerVM.player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {}
}

class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    private var playerLayer: AVPlayerLayer { 
        layer as! AVPlayerLayer 
    }
}
```

### Camera Integration

```swift
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
}
```

## Complete Implementation Example

Here's a production-ready implementation combining all best practices:

```swift
struct PlatformAdaptiveHomeView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedNavItem: NavItem?
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                RegularWidthLayout(selection: $selectedNavItem)
            } else {
                CompactWidthLayout(path: $navigationPath)
            }
        }
    }
}

struct RegularWidthLayout: View {
    @Binding var selection: NavItem?
    
    var body: some View {
        NavigationSplitView {
            List(NavItem.allItems, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MyApp")
        } detail: {
            if let selection {
                DetailView(item: selection)
            } else {
                ContentUnavailableView(
                    "Welcome",
                    systemImage: "hand.wave",
                    description: Text("Select an item to begin")
                )
            }
        }
    }
}

struct CompactWidthLayout: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        NavigationStack(path: $path) {
            List(NavItem.allItems) { item in
                NavigationLink(value: item) {
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text(item.title)
                        Spacer()
                        if item.badge > 0 {
                            Text("\(item.badge)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
            .navigationDestination(for: NavItem.self) { item in
                DetailView(item: item)
            }
        }
    }
}
```

## Best Practices and Key Principles

### Essential Practices for Native Feel

1. **Use appropriate list styles**: `.sidebar` for navigation on iPad/Mac, `.insetGrouped` for iPhone
2. **Respect platform selection patterns**: Edit mode on iOS, direct selection on macOS
3. **Implement proper empty states**: ContentUnavailableView with helpful guidance
4. **Match system spacing**: Default SwiftUI spacing typically provides correct results
5. **Support platform interactions**: Swipe actions on iOS, right-click on macOS
6. **Test across devices**: Verify appearance on iPhone SE through iPad Pro and Mac
7. **Handle dynamic type**: Ensure text scales appropriately with accessibility settings
8. **Provide keyboard navigation**: Essential for Mac, beneficial for iPad with keyboard

### Code Distribution Strategy

Building cross-platform productivity apps with SwiftUI requires mastering platform-specific behaviors while maximizing code reuse. The key is maintaining approximately **80% shared code with 20% platform-specific customizations**, primarily in navigation, visual effects, and interaction patterns.

### Performance Considerations

- Use background queues for processing
- Implement lazy loading for thumbnails
- Properly manage AVPlayer lifecycle to prevent memory leaks
- Leverage SwiftUI's automatic optimizations when possible

## Conclusion

Success in cross-platform SwiftUI development comes from understanding when to use adaptive components versus platform-specific implementations, leveraging system materials and colors for native appearance, and properly implementing navigation patterns that feel natural on each device. The framework's comprehensive APIs for multi-window support, navigation, keyboard shortcuts, and media handling provide the foundation for professional applications that deliver optimal user experience while maintaining development efficiency across Apple's ecosystem.