# SwiftUI Modern APIs Rules (iOS 18+ / macOS 15+)

## @Entry Macro

### DO: Use @Entry for Environment Values
✅ **ALWAYS use @Entry macro for custom environment values**

```swift
// Modern approach with @Entry
extension EnvironmentValues {
    @Entry var customTheme: Theme = .default
    @Entry var networkManager: NetworkManager = NetworkManager()
    @Entry var userPreferences: UserPreferences = UserPreferences()
}

// Usage
struct ContentView: View {
    @Environment(\.customTheme) private var theme
    @Environment(\.networkManager) private var networkManager
    
    var body: some View {
        Text("Hello")
            .foregroundColor(theme.primaryColor)
    }
}
```

### DO: Use @Entry for Focus Values
✅ **ALWAYS use @Entry for custom focus values**

```swift
extension FocusValues {
    @Entry var isEditing: Bool = false
    @Entry var currentField: FormField?
}

// Usage
struct FormView: View {
    @FocusState private var focusedField: FormField?
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focused($focusedField, equals: .name)
                .focusedValue(\.currentField, focusedField)
        }
    }
}
```

## Enhanced ScrollView APIs

### DO: ScrollView Position Control
✅ **ALWAYS use scrollPosition for scroll control**

```swift
struct ScrollPositionView: View {
    @State private var scrollPosition: CGPoint = .zero
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<100) { index in
                    Text("Item \(index)")
                        .frame(height: 50)
                        .id(index)
                }
            }
        }
        .scrollPosition($scrollPosition)
        .toolbar {
            Button("Scroll to Top") {
                withAnimation {
                    scrollPosition = .zero
                }
            }
        }
    }
}
```

### DO: Scroll Visibility Tracking
✅ **ALWAYS use onScrollVisibilityChange for lazy loading**

```swift
struct LazyLoadingView: View {
    @State private var items: [Item] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    ItemView(item: item)
                        .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                            if isVisible && item == items.last {
                                loadMoreItems()
                            }
                        }
                }
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
    }
    
    private func loadMoreItems() {
        // Implementation
    }
}
```

### DO: Scroll Geometry Observation
✅ **ALWAYS use onScrollGeometryChange for scroll-based effects**

```swift
struct ScrollEffectsView: View {
    @State private var isScrolledToTop = true
    
    var body: some View {
        ScrollView {
            VStack {
                // Content
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y <= 0
        } action: { wasAtTop, isAtTop in
            withAnimation {
                isScrolledToTop = isAtTop
            }
        }
        .navigationBarTitleDisplayMode(isScrolledToTop ? .large : .inline)
    }
}
```

## Enhanced TabView

### DO: Modern TabView with Customization
✅ **ALWAYS use modern TabView APIs**

```swift
struct ModernTabView: View {
    @State private var customization = TabViewCustomization()
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            .customizationID("home")
            
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }
            .customizationID("library")
            
            TabSection("Tools") {
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
                .customizationID("settings")
                
                Tab("Help", systemImage: "questionmark.circle") {
                    HelpView()
                }
                .customizationID("help")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}
```

### DO: Tab Sidebar Adaptability
✅ **ALWAYS implement sidebar adaptability**

```swift
struct AdaptiveTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    var body: some View {
        TabView {
            ForEach(TabItem.allCases) { tab in
                Tab(tab.title, systemImage: tab.icon) {
                    tab.destination
                }
                .customizationID(tab.id)
            }
        }
        .tabViewStyle(sizeClass == .compact ? .automatic : .sidebarAdaptable)
    }
}
```

## Navigation Transitions

### DO: Zoom Navigation Transitions
✅ **ALWAYS implement smooth zoom transitions**

```swift
struct ZoomTransitionView: View {
    @Namespace private var namespace
    
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns) {
                ForEach(items) { item in
                    NavigationLink {
                        DetailView(item: item)
                            .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                    } label: {
                        ItemThumbnail(item: item)
                            .matchedTransitionSource(id: item.id, in: namespace)
                    }
                }
            }
        }
    }
}
```

### DO: Custom Navigation Transitions
✅ **ALWAYS create smooth custom transitions**

```swift
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

struct CustomTransitionView: View {
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            Button("Show Detail") {
                withAnimation(.spring()) {
                    showDetail = true
                }
            }
            
            if showDetail {
                DetailView()
                    .transition(.slideAndFade)
            }
        }
    }
}
```

## Enhanced Text Rendering

### DO: Custom Text Rendering
✅ **ALWAYS use TextRenderer for advanced text effects**

```swift
struct CustomTextRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                // Draw shadow
                var shadowContext = context
                shadowContext.translateBy(x: 2, y: 2)
                shadowContext.addFilter(.blur(radius: 1))
                shadowContext.draw(run, options: .disablesSubpixelQuantization)
                
                // Draw main text
                context.draw(run)
            }
        }
    }
}

struct StyledTextView: View {
    var body: some View {
        Text("Custom Styled Text")
            .font(.largeTitle)
            .textRenderer(CustomTextRenderer())
    }
}
```

## Advanced List and Form APIs

### DO: Enhanced List Performance
✅ **ALWAYS optimize list performance with new APIs**

```swift
struct OptimizedListView: View {
    @State private var items: [Item] = []
    
    var body: some View {
        List(items) { item in
            ItemRow(item: item)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
        .refreshable {
            await refreshItems()
        }
    }
    
    private func refreshItems() async {
        // Refresh implementation
    }
}
```

### DO: Advanced Form Layouts
✅ **ALWAYS use modern form layouts**

```swift
struct ModernFormView: View {
    @State private var profile = UserProfile()
    
    var body: some View {
        Form {
            Section("Basic Information") {
                LabeledContent("Name") {
                    TextField("Enter name", text: $profile.name)
                }
                
                LabeledContent("Email") {
                    TextField("Enter email", text: $profile.email)
                        .keyboardType(.emailAddress)
                }
            }
            
            Section("Preferences") {
                LabeledContent("Theme") {
                    Picker("Theme", selection: $profile.theme) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
```

## Inspector and Side Panels

### DO: Inspector Implementation
✅ **ALWAYS implement inspectors for detail views**

```swift
struct InspectorView: View {
    @State private var selectedItem: Item?
    @State private var showInspector = false
    
    var body: some View {
        NavigationSplitView {
            ItemList(selection: $selectedItem)
        } detail: {
            if let item = selectedItem {
                ItemDetailView(item: item)
                    .inspector(isPresented: $showInspector) {
                        ItemInspector(item: item)
                            .inspectorColumnWidth(min: 200, ideal: 300, max: 400)
                    }
                    .toolbar {
                        Button("Inspector") {
                            showInspector.toggle()
                        }
                    }
            }
        }
    }
}
```

## Sensory Feedback

### DO: Haptic Feedback
✅ **ALWAYS provide appropriate haptic feedback**

```swift
struct HapticFeedbackView: View {
    @State private var isToggled = false
    
    var body: some View {
        VStack {
            Button("Action Button") {
                performAction()
            }
            .sensoryFeedback(.impact, trigger: isToggled)
            
            Toggle("Setting", isOn: $isToggled)
                .sensoryFeedback(.selection, trigger: isToggled)
        }
    }
    
    private func performAction() {
        withAnimation {
            isToggled.toggle()
        }
    }
}
```

## Content Transitions

### DO: Smooth Content Changes
✅ **ALWAYS use contentTransition for smooth updates**

```swift
struct ContentTransitionView: View {
    @State private var currentView: ViewType = .list
    
    var body: some View {
        VStack {
            Picker("View", selection: $currentView) {
                ForEach(ViewType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            Group {
                switch currentView {
                case .list:
                    ListView()
                case .grid:
                    GridView()
                case .chart:
                    ChartView()
                }
            }
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: currentView)
        }
    }
}
```

## Privacy and Security

### DO: Privacy-Sensitive Content
✅ **ALWAYS mark sensitive content appropriately**

```swift
struct PrivacySensitiveView: View {
    @State private var userEmail = "user@example.com"
    @State private var creditCard = "1234-5678-9012-3456"
    
    var body: some View {
        VStack {
            Text("Email: \(userEmail)")
                .privacySensitive()
            
            Text("Card: \(creditCard)")
                .privacySensitive()
                .redacted(reason: .privacy)
        }
    }
}
```

## Advanced Animations

### DO: Phase-Based Animations
✅ **ALWAYS use phase-based animations for complex sequences**

```swift
struct PhaseAnimationView: View {
    @State private var animationPhase = AnimationPhase.initial
    
    var body: some View {
        Circle()
            .fill(animationPhase.color)
            .frame(width: animationPhase.scale * 100, height: animationPhase.scale * 100)
            .offset(x: animationPhase.offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever()) {
                    animationPhase = .final
                }
            }
    }
}

enum AnimationPhase: CaseIterable {
    case initial, middle, final
    
    var color: Color {
        switch self {
        case .initial: return .blue
        case .middle: return .purple
        case .final: return .red
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .initial: return 1.0
        case .middle: return 1.5
        case .final: return 0.8
        }
    }
    
    var offset: CGFloat {
        switch self {
        case .initial: return 0
        case .middle: return 50
        case .final: return -30
        }
    }
}
```

## Keyboard and Input

### DO: Enhanced Keyboard Handling
✅ **ALWAYS implement advanced keyboard handling**

```swift
struct KeyboardHandlingView: View {
    @State private var text = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack {
            TextField("Enter text", text: $text)
                .focused($isFieldFocused)
                .onKeyPress(.return) {
                    submitText()
                    return .handled
                }
                .onKeyPress(.escape) {
                    isFieldFocused = false
                    return .handled
                }
                .onKeyPress(.tab) {
                    // Handle tab navigation
                    return .handled
                }
        }
        .onAppear {
            isFieldFocused = true
        }
    }
    
    private func submitText() {
        // Submit implementation
    }
}
```

## Container Relative Sizing

### DO: Container Relative Frames
✅ **ALWAYS use containerRelativeFrame for responsive design**

```swift
struct ResponsiveView: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    ItemCard(item: item)
                        .containerRelativeFrame(.horizontal) { width, axis in
                            min(width * 0.9, 400)
                        }
                        .containerRelativeFrame(.vertical) { height, axis in
                            height * 0.3
                        }
                }
            }
        }
    }
}
```

## Symbol Variants and Rendering

### DO: Advanced Symbol Usage
✅ **ALWAYS use symbol variants and rendering modes**

```swift
struct SymbolVariantsView: View {
    @State private var isConnected = false
    
    var body: some View {
        VStack {
            Image(systemName: "wifi")
                .symbolVariant(isConnected ? .none : .slash)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(isConnected ? .green : .red)
            
            Button("Toggle Connection") {
                withAnimation(.spring()) {
                    isConnected.toggle()
                }
            }
        }
    }
}
```

## Modern Gesture Handling

### DO: Enhanced Gesture Recognition
✅ **ALWAYS implement modern gesture patterns**

```swift
struct ModernGestureView: View {
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Rectangle()
            .fill(.blue)
            .frame(width: 200, height: 200)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                offset = .zero
                            }
                        },
                    
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                scale = 1.0
                            }
                        }
                )
            )
    }
}
```

## Anti-Patterns to Avoid

### DON'T: Modern API Mistakes
❌ **NEVER use old environment value patterns with @Entry available**
❌ **NEVER ignore scroll position APIs for scroll control**
❌ **NEVER skip haptic feedback for user interactions**
❌ **NEVER use hardcoded transitions when zoom transitions are available**
❌ **NEVER ignore privacy-sensitive content marking**

### DON'T: Performance Issues
❌ **NEVER use complex text rendering without performance testing**
❌ **NEVER ignore container relative sizing opportunities**
❌ **NEVER use outdated TabView patterns**
❌ **NEVER skip content transition animations**
❌ **NEVER ignore inspector opportunities in detail views**

## Migration Guidelines

### DO: Upgrade to Modern APIs
✅ **ALWAYS migrate to modern APIs systematically**

```swift
// Migration checklist for iOS 18 / macOS 15:
// [ ] Replace custom environment values with @Entry
// [ ] Implement scrollPosition for scroll control
// [ ] Add scroll visibility tracking for performance
// [ ] Upgrade TabView to use customization APIs
// [ ] Add navigation transitions where appropriate
// [ ] Implement sensory feedback for interactions
// [ ] Mark privacy-sensitive content
// [ ] Use container relative frames for responsive design
// [ ] Update symbol usage with variants
// [ ] Implement modern gesture handling
```