# SwiftUI Desktop Applications Rules (macOS & iPadOS Advanced Patterns)

## Advanced Window Management (macOS)

### DO: Use Window Scene Types Appropriately
✅ **ALWAYS choose the correct window scene type for each use case**

```swift
@main
struct DesktopApp: App {
    var body: some Scene {
        // Primary document windows (multiple instances)
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        
        // Single-instance utility windows
        Window("Inspector", id: "inspector") {
            InspectorView()
        }
        .defaultPosition(.trailing)
        .windowResizability(.contentSize)
        .keyboardShortcut("i", modifiers: [.command, .option])
        
        // Floating panels
        Window("Tools", id: "tools") {
            ToolsPanelView()
        }
        .windowLevel(.floating)
        .windowStyle(.plain)
        .windowBackgroundDragBehavior(.enabled)
    }
}
```

### DO: Advanced Window Positioning and Sizing
✅ **ALWAYS use precise window placement for professional applications**

```swift
// Custom window placement with display awareness
WindowGroup("Video Player") {
    VideoPlayerView()
}
.defaultWindowPlacement { content, context in
    let size = content.sizeThatFits(.unspecified)
    let displayBounds = context.defaultDisplay.visibleRect
    
    // Position near bottom-right of display
    let position = CGPoint(
        x: displayBounds.maxX - size.width - 50,
        y: displayBounds.maxY - size.height - 100
    )
    
    return WindowPlacement(position, size: size)
}
.windowResizability(.contentSize)
```

### DO: Window State Management with @SceneStorage
✅ **ALWAYS preserve window state across app launches**

```swift
struct ContentView: View {
    @SceneStorage("sidebarVisible") private var sidebarVisible = true
    @SceneStorage("selectedTab") private var selectedTab = 0
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            TabView(selection: $selectedTab) {
                DocumentsView()
                    .tabItem { Label("Documents", systemImage: "doc") }
                    .tag(0)
                ProjectsView()
                    .tabItem { Label("Projects", systemImage: "folder") }
                    .tag(1)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            Button("Tools") {
                openWindow(id: "tools")
            }
        }
    }
}
```

### DON'T: Ignore Window Resizability Options
❌ **NEVER use default resizability without considering user experience**

```swift
// Bad: No consideration for content constraints
Window("Fixed Panel", id: "panel") {
    FixedSizePanel()
}
// Missing: .windowResizability(.contentSize)

// Good: Appropriate resizability for content type
Window("Settings Panel", id: "settings") {
    SettingsPanel()
}
.windowResizability(.contentSize) // Fixed size for settings
.windowMinimizeBehavior(.disabled) // Disable minimize for utility panels
```

## Menu Bar Integration & Commands API

### DO: Comprehensive Menu Structure
✅ **ALWAYS implement sophisticated menu systems for desktop applications**

```swift
@main
struct DesktopApp: App {
    @StateObject private var appState = AppState()
    @FocusedValue(\.document) var document: Binding<Document>?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            // Custom menus
            CommandMenu("Tools") {
                Button("Process Selection") {
                    processSelection()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(document?.wrappedValue.selection.isEmpty ?? true)
                
                Divider()
                
                Menu("Export") {
                    Button("Export as PDF") { exportPDF() }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                    Button("Export as Image") { exportImage() }
                        .keyboardShortcut("e", modifiers: [.command, .option])
                }
                
                Toggle("Live Preview", isOn: $appState.livePreviewEnabled)
                    .keyboardShortcut("l", modifiers: [.command])
            }
            
            // Enhance existing menus
            CommandGroup(after: .newItem) {
                Button("New from Template") {
                    createFromTemplate()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            // Document-specific commands
            DocumentCommands()
            TextEditingCommands()
            TextFormattingCommands()
        }
    }
}
```

### DO: Menu Bar Extra Applications
✅ **ALWAYS implement menu bar extras with appropriate styles**

```swift
@main
struct MenuBarApp: App {
    @StateObject private var statusManager = StatusManager()
    
    var body: some Scene {
        // Rich popover-style menu bar extra
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(statusManager)
                .frame(width: 320, height: 400)
        } label: {
            Label("MyApp", systemImage: statusManager.statusIcon)
                .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.window)
        
        // Main app window (optional)
        WindowGroup {
            MainAppView()
                .environmentObject(statusManager)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var statusManager: StatusManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StatusHeaderView(status: statusManager.currentStatus)
                
                Divider()
                
                QuickActionsView()
                
                Divider()
                
                RecentItemsView(items: statusManager.recentItems)
                
                Spacer()
                
                HStack {
                    Button("Preferences") {
                        openWindow(id: "preferences")
                    }
                    .keyboardShortcut(",")
                    
                    Spacer()
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding()
        }
    }
}
```

### DO: Focus-Based Command Coordination
✅ **ALWAYS coordinate commands across multiple windows using FocusedValues**

```swift
// Define focus value for document coordination
struct DocumentFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Document>
}

extension FocusedValues {
    var document: Binding<Document>? {
        get { self[DocumentFocusedValueKey.self] }
        set { self[DocumentFocusedValueKey.self] = newValue }
    }
}

// Provide focus value in document view
struct DocumentView: View {
    @State private var document: Document
    
    var body: some View {
        DocumentEditor(document: $document)
            .focusedValue(\.document, $document)
            .focusable()
    }
}

// Consume in commands
struct DocumentCommands: Commands {
    @FocusedValue(\.document) var document: Binding<Document>?
    
    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Word Count") {
                if let doc = document {
                    showWordCount(for: doc.wrappedValue)
                }
            }
            .keyboardShortcut("w", modifiers: [.command, .control])
            .disabled(document == nil)
            
            Button("Export as Markdown") {
                if let doc = document {
                    exportMarkdown(doc.wrappedValue)
                }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(document == nil)
        }
    }
}
```

## Advanced iPadOS Keyboard Navigation & Focus Management

### DO: Sophisticated Focus Management
✅ **ALWAYS implement comprehensive keyboard navigation for iPad productivity apps**

```swift
struct KeyboardFirstFormView: View {
    @FocusState private var focusedField: FormField?
    @State private var formData = FormData()
    
    enum FormField: CaseIterable, Hashable {
        case title, subtitle, content, tags, category
        
        var next: FormField? {
            let all = FormField.allCases
            guard let index = all.firstIndex(of: self),
                  index < all.count - 1 else { return nil }
            return all[index + 1]
        }
    }
    
    var body: some View {
        Form {
            TextField("Title", text: $formData.title)
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .subtitle }
                .submitLabel(.next)
            
            TextField("Subtitle", text: $formData.subtitle)
                .focused($focusedField, equals: .subtitle)
                .onSubmit { focusedField = .content }
                .submitLabel(.next)
            
            TextEditor(text: $formData.content)
                .focused($focusedField, equals: .content)
                .frame(minHeight: 100)
                .focusable(interactions: .edit)
            
            TextField("Tags", text: $formData.tags)
                .focused($focusedField, equals: .tags)
                .onSubmit { focusedField = .category }
                .submitLabel(.next)
            
            Picker("Category", selection: $formData.categoryId) {
                ForEach(categories) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .focused($focusedField, equals: .category)
            .onSubmit { submitForm() }
        }
        .defaultFocus($focusedField, .title)
        .onKeyPress(.tab) { 
            advanceFocus()
            return .handled
        }
        .onKeyPress(.tab, modifiers: .shift) {
            reverseFocus()
            return .handled
        }
    }
    
    private func advanceFocus() {
        focusedField = focusedField?.next ?? .title
    }
    
    private func reverseFocus() {
        let all = FormField.allCases
        guard let current = focusedField,
              let index = all.firstIndex(of: current),
              index > 0 else {
            focusedField = all.last
            return
        }
        focusedField = all[index - 1]
    }
}
```

### DO: Advanced Arrow Key Navigation
✅ **ALWAYS implement arrow key navigation for custom grid layouts**

```swift
struct KeyboardNavigableGrid: View {
    @State private var items: [GridItem] = []
    @State private var selectedItemId: GridItem.ID?
    @Environment(\.layoutDirection) private var layoutDirection
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    GridItemView(
                        item: item,
                        isSelected: item.id == selectedItemId
                    )
                    .onTapGesture {
                        selectedItemId = item.id
                    }
                }
            }
            .padding()
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            handleArrowNavigation(direction)
        }
        .onKeyPress(.return) {
            if let selectedId = selectedItemId {
                activateItem(selectedId)
            }
            return .handled
        }
        .onKeyPress(.space) {
            if let selectedId = selectedItemId {
                toggleSelection(selectedId)
            }
            return .handled
        }
    }
    
    private func handleArrowNavigation(_ direction: MoveCommandDirection) {
        guard let currentId = selectedItemId,
              let currentIndex = items.firstIndex(where: { $0.id == currentId })
        else {
            selectedItemId = items.first?.id
            return
        }
        
        let columnsCount = 4
        var newIndex = currentIndex
        
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - columnsCount)
        case .down:
            newIndex = min(items.count - 1, currentIndex + columnsCount)
        case .left:
            if layoutDirection == .rightToLeft {
                newIndex = min(items.count - 1, currentIndex + 1)
            } else {
                newIndex = max(0, currentIndex - 1)
            }
        case .right:
            if layoutDirection == .rightToLeft {
                newIndex = max(0, currentIndex - 1)
            } else {
                newIndex = min(items.count - 1, currentIndex + 1)
            }
        @unknown default:
            break
        }
        
        selectedItemId = items[newIndex].id
    }
}
```

### DO: Pointer and Trackpad Integration
✅ **ALWAYS implement sophisticated pointer interactions for iPad**

```swift
struct PointerInteractiveView: View {
    @State private var isHovered = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: isHovered ? [.blue, .purple] : [.gray, .secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 200, height: 150)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .offset(dragOffset)
            .hoverEffect(.lift)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovered = true
                    hoverLocation = location
                    updateHoverEffects(at: location)
                case .ended:
                    isHovered = false
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            // Handle zoom
                        },
                    RotationGesture()
                        .onChanged { rotation in
                            // Handle rotation
                        }
                )
            )
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private func updateHoverEffects(at location: CGPoint) {
        // Implement hover-based visual effects
        // Could add particle effects, highlight regions, etc.
    }
}
```

## Document-Based Applications

### DO: Complete Document Architecture
✅ **ALWAYS implement full document-based app architecture**

```swift
@main
struct DocumentApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            DocumentView(document: file.$document)
        }
        .commands {
            DocumentCommands()
            TextEditingCommands()
            TextFormattingCommands()
        }
    }
}

struct TextDocument: FileDocument, Codable {
    var text: String
    var metadata: DocumentMetadata
    
    static var readableContentTypes: [UTType] = [.plainText, .json]
    static var writableContentTypes: [UTType] = [.plainText]
    
    init(initialText: String = "") {
        self.text = initialText
        self.metadata = DocumentMetadata()
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        if configuration.contentType == .json {
            let decoder = JSONDecoder()
            let document = try decoder.decode(TextDocument.self, from: data)
            self = document
        } else {
            guard let string = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            self.text = string
            self.metadata = DocumentMetadata()
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if configuration.contentType == .json {
            let data = try encoder.encode(self)
            return FileWrapper(regularFileWithContents: data)
        } else {
            let data = text.data(using: .utf8) ?? Data()
            return FileWrapper(regularFileWithContents: data)
        }
    }
}

struct DocumentMetadata: Codable {
    var createdDate = Date()
    var wordCount: Int = 0
    var lastModified = Date()
    var tags: [String] = []
}
```

### DO: Advanced File Operations with Security
✅ **ALWAYS handle security-scoped resources properly**

```swift
struct DocumentView: View {
    @Binding var document: TextDocument
    @State private var showingImporter = false
    @State private var showingExporter = false
    
    var body: some View {
        TextEditor(text: $document.text)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Import") {
                        showingImporter = true
                    }
                    
                    Button("Export") {
                        showingExporter = true
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText, .markdown],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: document,
                contentType: .plainText,
                defaultFilename: "Export"
            ) { result in
                handleExport(result)
            }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Security-scoped resource handling
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let content = try String(contentsOf: url)
                document.text = content
                document.metadata.lastModified = Date()
            } catch {
                // Handle error appropriately
                print("Import failed: \(error)")
            }
            
        case .failure(let error):
            // Handle error appropriately
            print("File selection failed: \(error)")
        }
    }
    
    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Successfully exported to: \(url)")
        case .failure(let error):
            print("Export failed: \(error)")
        }
    }
}
```


## Performance Optimization for Desktop

### DO: Use Table for Better Performance
✅ **ALWAYS prefer Table over List for desktop applications with tabular data**

```swift
struct OptimizedDataTable: View {
    @State private var items: [DataItem] = []
    @State private var selection = Set<DataItem.ID>()
    @State private var sortOrder = [KeyPathComparator(\DataItem.name)]
    
    var body: some View {
        Table(items, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(item.statusColor)
                    Text(item.name)
                        .fontWeight(.medium)
                }
            }
            .width(min: 200, ideal: 300, max: 400)
            
            TableColumn("Status") { item in
                StatusBadge(status: item.status)
            }
            .width(80)
            
            TableColumn("Modified") { item in
                Text(item.modifiedDate, style: .relative)
                    .foregroundStyle(.secondary)
            }
            .width(100)
            
            TableColumn("Size") { item in
                Text(item.fileSize, format: .byteCount(style: .file))
                    .monospacedDigit()
            }
            .width(80)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: DataItem.ID.self) { items in
            contextMenuItems(for: items)
        }
        .onChange(of: sortOrder) { _, newOrder in
            items.sort(using: newOrder)
        }
        .task {
            await loadItems()
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for items: Set<DataItem.ID>) -> some View {
        if items.count == 1 {
            Button("Open") {
                openItem(items.first!)
            }
            .keyboardShortcut(.return)
            
            Button("Duplicate") {
                duplicateItem(items.first!)
            }
            .keyboardShortcut("d", modifiers: .command)
        }
        
        Button("Delete", role: .destructive) {
            deleteItems(items)
        }
        .keyboardShortcut(.delete)
        
        if items.count > 1 {
            Text("\(items.count) items selected")
        }
    }
}
```

### DO: Optimize View Performance with DrawingGroup
✅ **ALWAYS use drawingGroup for complex repeated views**

```swift
struct OptimizedComplexList: View {
    let items: [ComplexItem]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ComplexItemRow(item: item)
                        .drawingGroup() // Rasterize complex views
                        .task {
                            // Load additional data if needed
                            await item.loadThumbnailIfNeeded()
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
    }
}

struct ComplexItemRow: View {
    let item: ComplexItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        TagView(tag: tag)
                    }
                    
                    if item.tags.count > 3 {
                        Text("+\(item.tags.count - 3)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(item.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                StatusIndicator(status: item.status)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### DON'T: Overuse Advanced Features
❌ **NEVER apply complex effects to every view without performance consideration**

```swift
// Bad: Excessive effects on every item in a list
ForEach(items) { item in
    ItemView(item: item)
        .distortionEffect(ShaderLibrary.wave(.float(time)), maxSampleOffset: .init(width: 10, height: 10))
        .colorEffect(ShaderLibrary.gradient(.float(progress)))
        .layerEffect(ShaderLibrary.blur(.float(2.0)), maxSampleOffset: .init(width: 5, height: 5))
}

// Good: Apply effects selectively and conditionally
ForEach(items) { item in
    ItemView(item: item)
        .conditionalEffect(isHighlighted: item.isSelected) {
            $0.colorEffect(ShaderLibrary.highlight(.float(0.3)))
        }
}

extension View {
    func conditionalEffect<T: View>(
        isHighlighted: Bool,
        @ViewBuilder effect: @escaping (Self) -> T
    ) -> some View {
        if isHighlighted {
            effect(self)
        } else {
            self
        }
    }
}
```

## Context Menus and Advanced Interactions

### DO: Rich Context Menus with Keyboard Support
✅ **ALWAYS implement comprehensive context menus with keyboard shortcuts**

```swift
struct AdvancedContextMenuView: View {
    @State private var selectedItems: Set<Item.ID> = []
    @State private var items: [Item] = []
    
    var body: some View {
        List(items, selection: $selectedItems) { item in
            ItemRowView(item: item)
                .contextMenu {
                    contextMenuContent(for: item)
                }
        }
        .contextMenu(forSelectionType: Item.ID.self) { selection in
            multiSelectionContextMenu(for: selection)
        }
    }
    
    @ViewBuilder
    private func contextMenuContent(for item: Item) -> some View {
        Button("Open") {
            openItem(item)
        }
        .keyboardShortcut(.return)
        
        Button("Open in New Window") {
            openItemInNewWindow(item)
        }
        .keyboardShortcut(.return, modifiers: .command)
        
        Divider()
        
        Button("Duplicate") {
            duplicateItem(item)
        }
        .keyboardShortcut("d", modifiers: .command)
        
        Button("Rename") {
            renameItem(item)
        }
        .keyboardShortcut(.return, modifiers: [])
        
        Divider()
        
        Menu("Share") {
            ShareLink(item: item.url) {
                Label("Share Link", systemImage: "link")
            }
            
            Button("Copy to Clipboard") {
                copyToClipboard(item)
            }
            .keyboardShortcut("c", modifiers: .command)
        }
        
        Divider()
        
        Button("Move to Trash", role: .destructive) {
            moveToTrash(item)
        }
        .keyboardShortcut(.delete)
    }
    
    @ViewBuilder
    private func multiSelectionContextMenu(for selection: Set<Item.ID>) -> some View {
        let count = selection.count
        
        if count > 1 {
            Text("\(count) items selected")
                .foregroundStyle(.secondary)
            
            Divider()
            
            Button("Open All") {
                openItems(Array(selection))
            }
            
            Button("Duplicate All") {
                duplicateItems(Array(selection))
            }
            
            Divider()
            
            Button("Move \(count) Items to Trash", role: .destructive) {
                moveItemsToTrash(Array(selection))
            }
            .keyboardShortcut(.delete)
        }
    }
}
```

## Platform-Specific UI Patterns

### DO: Adaptive Toolbar Configurations
✅ **ALWAYS implement platform-appropriate toolbar styles**

```swift
struct AdaptiveToolbarView: View {
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .list
    @State private var showingSidebar = true
    
    enum ViewMode: CaseIterable {
        case list, grid, column
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            case .column: return "rectangle.split.3x1"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ContentView(viewMode: viewMode)
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button {
                    showingSidebar.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
            #endif
            
            ToolbarItem(placement: .principal) {
                #if os(macOS)
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                #else
                Menu {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Button {
                            viewMode = mode
                        } label: {
                            Label(String(describing: mode).capitalized, 
                                  systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: viewMode.icon)
                }
                #endif
            }
            
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    #if os(macOS)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit {
                            performSearch()
                        }
                    #else
                    Button("Search") {
                        // Show search interface
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    #endif
                    
                    Button("Add") {
                        addNewItem()
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .navigationTitle("Items")
        #if os(macOS)
        .navigationSubtitle("\(itemCount) items")
        .toolbarBackground(.regularMaterial, for: .windowToolbar)
        #endif
    }
}
```

### DO: Advanced Window Coordination
✅ **ALWAYS coordinate state between multiple windows properly**

```swift
@MainActor
@Observable
class WindowCoordinator {
    static let shared = WindowCoordinator()
    
    var openWindows: [String: WindowInfo] = [:]
    var activeWindowId: String?
    var sharedState = SharedAppState()
    
    struct WindowInfo {
        let id: String
        let type: WindowType
        var isActive: Bool = false
        var bounds: CGRect = .zero
    }
    
    enum WindowType {
        case main, inspector, document(id: String), utility
    }
    
    func registerWindow(_ id: String, type: WindowType) {
        openWindows[id] = WindowInfo(id: id, type: type)
    }
    
    func unregisterWindow(_ id: String) {
        openWindows.removeValue(forKey: id)
        if activeWindowId == id {
            activeWindowId = openWindows.keys.first
        }
    }
    
    func setActiveWindow(_ id: String) {
        // Update all windows' active state
        for (windowId, _) in openWindows {
            openWindows[windowId]?.isActive = (windowId == id)
        }
        activeWindowId = id
    }
    
    func cascadeNewWindow(from sourceId: String) -> CGPoint {
        guard let sourceWindow = openWindows[sourceId] else {
            return CGPoint(x: 100, y: 100)
        }
        
        return CGPoint(
            x: sourceWindow.bounds.origin.x + 30,
            y: sourceWindow.bounds.origin.y + 30
        )
    }
}

// Use in window scenes
struct CoordinatedWindow: View {
    let windowId: String
    let windowType: WindowCoordinator.WindowType
    @Environment(WindowCoordinator.self) private var coordinator
    
    var body: some View {
        ContentView()
            .onAppear {
                coordinator.registerWindow(windowId, type: windowType)
            }
            .onDisappear {
                coordinator.unregisterWindow(windowId)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                coordinator.setActiveWindow(windowId)
            }
    }
}
```

These rules provide comprehensive guidance for building sophisticated desktop and tablet applications with SwiftUI, focusing on the advanced features that differentiate professional applications from basic mobile apps. The patterns emphasize proper keyboard navigation, window management, performance optimization, and platform-specific user experience expectations.