# SwiftUI Cross-Platform Development Rules

## Platform Detection and Adaptation

### DO: Code Sharing Strategy
✅ **ALWAYS aim for 90%+ shared code between platforms**
- Use platform conditionals (#if os()) sparingly
- Focus on adaptive UI components
- Share business logic completely

```swift
// Good: Shared ViewModel across platforms
@MainActor
@Observable
class UserViewModel {
    var users: [User] = []
    var isLoading = false
    
    // 100% shared logic
    func loadUsers() async {
        isLoading = true
        // Implementation shared across platforms
        users = await userService.fetchUsers()
        isLoading = false
    }
}

// Platform-specific UI only
struct UserListView: View {
    @State private var viewModel = UserViewModel()
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            listContent
        }
        #elseif os(macOS)
        NavigationSplitView {
            listContent
        } detail: {
            DetailView()
        }
        #endif
    }
    
    private var listContent: some View {
        List(viewModel.users) { user in
            UserRow(user: user)
        }
    }
}
```

### DO: Platform-Specific Modifiers
✅ **ALWAYS use platform-specific modifiers judiciously**

```swift
extension View {
    func platformOptimized() -> some View {
        self
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            #elseif os(macOS)
            .navigationSubtitle("macOS Version")
            .frame(minWidth: 400, minHeight: 300)
            #endif
    }
}
```

## Multi-Platform Architecture

### DO: Single Target Architecture
✅ **ALWAYS use single multiplatform target**

```swift
// Project structure
MyApp/
├── Shared/
│   ├── ViewModels/
│   ├── Services/
│   ├── Models/
│   └── Utilities/
├── iOS/
│   └── iOSSpecificViews/
├── macOS/
│   └── macOSSpecificViews/
└── Multiplatform/
    └── SharedViews/
```

### DO: Platform-Adaptive Navigation
✅ **ALWAYS implement platform-adaptive navigation**

```swift
struct AdaptiveNavigationView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad and Mac
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
        } else {
            // iPhone
            NavigationStack {
                CompactView()
            }
        }
    }
}
```

## Form Patterns

### DO: Platform-Adaptive Forms
✅ **ALWAYS adapt forms to platform conventions**

```swift
struct AdaptiveFormView: View {
    @State private var name = ""
    @State private var email = ""
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
            }
        }
        .formStyle(platformFormStyle)
    }
    
    private var platformFormStyle: any FormStyle {
        #if os(iOS)
        return .grouped
        #elseif os(macOS)
        return .columns
        #endif
    }
}
```

### DO: FormStyle Selection
✅ **ALWAYS choose appropriate FormStyle**

```swift
// iOS: Use .grouped or .automatic
Form {
    // Content
}
.formStyle(.grouped)

// macOS: Use .columns for two-column layout
Form {
    LabeledContent("Name", value: user.name)
    LabeledContent("Email", value: user.email)
}
.formStyle(.columns)
```

## Navigation Patterns

### DO: NavigationSplitView Configuration
✅ **ALWAYS configure NavigationSplitView properly**

```swift
struct MainNavigationView: View {
    @State private var selectedItem: NavigationItem?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            if let selectedItem {
                DetailView(item: selectedItem)
            } else {
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "sidebar.left",
                    description: Text("Choose something from the sidebar")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### DO: Adaptive Navigation State
✅ **ALWAYS manage navigation state across platforms**

```swift
@MainActor
class NavigationManager: ObservableObject {
    @Published var splitViewSelection: NavigationItem?
    @Published var stackPath = NavigationPath()
    
    func navigate(to item: NavigationItem) {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewSelection = item
        } else {
            stackPath.append(item)
        }
        #elseif os(macOS)
        splitViewSelection = item
        #endif
    }
}
```

## Platform-Specific Styling

### DO: System Materials and Colors
✅ **ALWAYS use system-appropriate styling**

```swift
struct PlatformAdaptiveCard: View {
    var body: some View {
        VStack {
            Text("Card Content")
                .padding()
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    private var cardBackground: some ShapeStyle {
        #if os(iOS)
        return .regularMaterial
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    private var cornerRadius: CGFloat {
        #if os(iOS)
        return 12
        #elseif os(macOS)
        return 8
        #endif
    }
}
```

### DO: Platform-Specific Spacing
✅ **ALWAYS use platform-appropriate spacing**

```swift
struct AdaptiveSpacingView: View {
    var body: some View {
        VStack(spacing: platformSpacing) {
            Text("Title")
                .font(.title2)
            Text("Content")
                .font(.body)
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
    
    private var platformPadding: EdgeInsets {
        #if os(iOS)
        return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        #elseif os(macOS)
        return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        #endif
    }
}
```

## Control Adaptations

### DO: Platform-Specific Controls
✅ **ALWAYS use platform-appropriate controls**

```swift
struct AdaptiveControlsView: View {
    @State private var isEnabled = false
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField("Input", text: $text)
                .textFieldStyle(platformTextFieldStyle)
            
            Toggle("Enable Feature", isOn: $isEnabled)
                .toggleStyle(platformToggleStyle)
        }
    }
    
    private var platformTextFieldStyle: any TextFieldStyle {
        #if os(iOS)
        return .roundedBorder
        #elseif os(macOS)
        return .plain
        #endif
    }
    
    private var platformToggleStyle: any ToggleStyle {
        #if os(iOS)
        return .switch
        #elseif os(macOS)
        return .checkbox
        #endif
    }
}
```

## Multi-Window Support

### DO: Window Management
✅ **ALWAYS implement proper window management**

```swift
@main
struct MultiPlatformApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        #endif
        
        #if os(macOS)
        Window("Inspector", id: "inspector") {
            InspectorView()
        }
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        #endif
    }
}
```

## Keyboard and Input

### DO: Keyboard Shortcuts
✅ **ALWAYS implement keyboard shortcuts for common actions**

```swift
struct KeyboardShortcutView: View {
    var body: some View {
        VStack {
            Button("Save") {
                save()
            }
            .keyboardShortcut("s", modifiers: .command)
            
            Button("New Item") {
                createNew()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        #if os(macOS)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        #endif
    }
}
```

### DO: Context Menus
✅ **ALWAYS implement platform-appropriate context menus**

```swift
struct ContextMenuView: View {
    var body: some View {
        Text("Right-click me")
            .contextMenu {
                Button("Edit", systemImage: "pencil") {
                    edit()
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete()
                }
            }
    }
}
```

## Modern iOS 18 / macOS 15 Features

### DO: Enhanced TabView
✅ **ALWAYS use sidebarAdaptable for modern tab interfaces**

```swift
struct ModernTabView: View {
    @State private var customization = TabViewCustomization()
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}
```

### DO: Navigation Transitions
✅ **ALWAYS implement smooth navigation transitions**

```swift
struct TransitionNavigationView: View {
    @Namespace private var namespace
    
    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink {
                    DetailView(item: item)
                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                } label: {
                    ItemRow(item: item)
                }
                .matchedTransitionSource(id: item.id, in: namespace)
            }
        }
    }
}
```

## Menu Bar Integration

### DO: MenuBarExtra (macOS)
✅ **ALWAYS implement MenuBarExtra for system integration**

```swift
@main
struct MenuBarApp: App {
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("MyApp", systemImage: "star") {
            VStack {
                Button("Quick Action") {
                    // Quick action
                }
                
                Divider()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .frame(width: 200)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
```

## Testing Cross-Platform Code

### DO: Platform-Specific Testing
✅ **ALWAYS test on all target platforms**

```swift
@Test("Cross-platform navigation works correctly")
func testCrossPlatformNavigation() {
    let viewModel = NavigationViewModel()
    
    #if os(iOS)
    viewModel.navigateToDetail(item: testItem)
    #expect(viewModel.navigationPath.count == 1)
    #elseif os(macOS)
    viewModel.selectItem(testItem)
    #expect(viewModel.selectedItem == testItem)
    #endif
}
```

### DO: Adaptive Layout Testing
✅ **ALWAYS test adaptive layouts**

```swift
@Test("Layout adapts to different size classes")
func testAdaptiveLayout() {
    let view = AdaptiveView()
    
    // Test compact layout
    let compactView = view.environment(\.horizontalSizeClass, .compact)
    #expect(compactView.usesCompactLayout)
    
    // Test regular layout
    let regularView = view.environment(\.horizontalSizeClass, .regular)
    #expect(regularView.usesRegularLayout)
}
```

## Performance Optimization

### DO: Platform-Specific Optimizations
✅ **ALWAYS optimize for platform capabilities**

```swift
struct OptimizedListView: View {
    let items: [Item]
    
    var body: some View {
        #if os(iOS)
        List(items) { item in
            ItemRow(item: item)
        }
        .listStyle(.insetGrouped)
        #elseif os(macOS)
        List(items) { item in
            ItemRow(item: item)
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        #endif
    }
}
```

## Error Handling

### DO: Platform-Appropriate Error Presentation
✅ **ALWAYS present errors appropriately per platform**

```swift
struct ErrorHandlingView: View {
    @State private var error: Error?
    @State private var showAlert = false
    
    var body: some View {
        ContentView()
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        
        #if os(iOS)
        showAlert = true
        #elseif os(macOS)
        NSAlert(error: error).runModal()
        #endif
    }
}
```

## Platform Detection Helpers

### DO: Create Platform Utilities
✅ **ALWAYS create reusable platform detection utilities**

```swift
enum Platform {
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isCompact: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
}
```

## Anti-Patterns to Avoid

### DON'T: Cross-Platform Mistakes
❌ **NEVER assume platform-specific APIs exist everywhere**
❌ **NEVER hardcode platform-specific values**
❌ **NEVER ignore platform design guidelines**
❌ **NEVER use excessive platform conditionals**
❌ **NEVER skip testing on all platforms**

### DON'T: Common Platform Errors
❌ **NEVER use UIKit/AppKit directly in shared code**
❌ **NEVER ignore size class changes**
❌ **NEVER use platform-specific navigation patterns globally**
❌ **NEVER skip accessibility on any platform**
❌ **NEVER use non-adaptive layouts**

## Code Distribution Guidelines

### DO: Maintain Code Sharing Balance
✅ **ALWAYS maintain 90% shared code target**

**Shared Code (90%):**
- ViewModels and business logic
- Services and networking
- Models and data structures
- Utilities and extensions

**Platform-Specific Code (10%):**
- Navigation structure
- Platform-specific UI components
- System integration features
- Platform-specific optimizations

### DO: Regular Platform Testing
✅ **ALWAYS test regularly on all platforms**

```swift
// Test matrix
// iOS iPhone: Portrait, Landscape
// iOS iPad: Portrait, Landscape, Split View
// macOS: Various window sizes
// All platforms: Dark mode, accessibility
```