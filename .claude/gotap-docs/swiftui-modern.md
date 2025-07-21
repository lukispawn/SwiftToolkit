# SwiftUI Development Best Practices and Rules (iOS 18+ & macOS 15+)

## Table of Contents
1. [Project Setup](#project-setup)
2. [State Management and Observation](#state-management-and-observation)
3. [Async/Await Patterns](#asyncawait-patterns)
4. [Code Organization](#code-organization)
5. [Navigation Patterns](#navigation-patterns)
6. [Native Components](#native-components)
7. [ScrollView and Modern APIs](#scrollview-and-modern-apis)
8. [Sheet Presentation](#sheet-presentation)
9. [Toolbar Management](#toolbar-management)
10. [MVVM Architecture](#mvvm-architecture-with-service-pattern)
11. [Preview Macros](#preview-macros)
12. [Performance Optimization](#performance-optimization)
13. [SwiftData Integration](#swiftdata-integration)
14. [Keyboard and Search](#keyboard-and-search)
15. [Design System](#design-system)
16. [Multi-Platform Support](#multi-platform-support)
17. [Accessibility](#accessibility)
18. [Localization](#localization)
19. [Error Handling](#error-handling)
20. [Testing Strategies](#testing-strategies)
21. [Animation Best Practices](#animation-best-practices)
22. [Environment Values and Preferences](#environment-values-and-preferences)
23. [Focus Management](#focus-management)
24. [State Restoration](#state-restoration)
25. [Gesture Best Practices](#gesture-best-practices)
26. [Image Loading and Caching](#image-loading-and-caching)
27. [Custom Transitions](#custom-transitions)
28. [Memory Management](#memory-management)
29. [Conditional View Modifiers](#conditional-view-modifiers)
30. [Debug Helpers](#debug-helpers)
31. [macOS Development Best Practices](#macos-development-best-practices)
32. [Advanced SwiftUI Patterns](#advanced-swiftui-patterns)

---

## 1. Project Setup

### Minimum Deployment Target
```swift
// RULE: All new projects start with iOS 18.0 and macOS 15.0 minimum
// In project settings:
iOS Deployment Target: 18.0
macOS Deployment Target: 15.0
```

### Single Target Architecture

**✅ DO: Use single target for all platforms**
```swift
// Create Multiplatform App in Xcode
// File > New > Project > Multiplatform > App
// This creates a single target that runs on all platforms
```

**Platform Conditionals**
```swift
// Use compile-time checks for platform-specific code
#if os(iOS)
    // iOS-specific code
#elseif os(macOS)
    // macOS-specific code
#elseif os(watchOS)
    // watchOS-specific code
#elseif os(tvOS)
    // tvOS-specific code
#endif

// Use runtime checks when needed
if UIDevice.current.userInterfaceIdiom == .phone {
    // iPhone specific
} else if UIDevice.current.userInterfaceIdiom == .pad {
    // iPad specific
}
```

**Project Structure for Single Target**
```
MyApp/
├── MyAppApp.swift                 // @main entry point
├── Models/
├── ViewModels/
├── Views/
│   ├── Shared/                   // Views used on all platforms
│   │   ├── Components/
│   │   └── Screens/
│   ├── iOS/                      // iOS-specific views
│   └── macOS/                    // macOS-specific views
├── Services/
├── Extensions/
│   ├── View+Extensions.swift
│   ├── View+iOS.swift           // iOS-specific extensions
│   └── View+macOS.swift         // macOS-specific extensions
└── Resources/
    ├── Assets.xcassets          // Shared assets
    └── Localizable.xcstrings    // Shared localizations
```

### App Entry Point

```swift
// MyAppApp.swift - Single entry point for all platforms
import SwiftUI

@main
struct MyAppApp: App {
    // Shared state
    @StateObject private var appState = AppState()
    
    // Platform-specific setup
    init() {
        #if os(macOS)
        setupMacOS()
        #elseif os(iOS)
        setupIOS()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
        #endif
        
        #if os(macOS)
        // Additional scenes for macOS
        Settings {
            SettingsView()
        }
        #endif
    }
    
    #if os(macOS)
    private func setupMacOS() {
        // macOS-specific setup
        NSApplication.shared.setActivationPolicy(.regular)
    }
    #endif
    
    #if os(iOS)
    private func setupIOS() {
        // iOS-specific setup
    }
    #endif
}
```

### Required Configuration
- **Single Multiplatform target** for all Apple platforms
- Share 90%+ of code between platforms
- Use platform conditionals only when necessary
- Design with all platforms in mind from the start

---

## 2. State Management and Observation

### Modern @Observable Pattern (iOS 17+)

**✅ DO: Use @Observable for all ViewModels**
```swift
import Observation

@Observable
class UserViewModel {
    var users: [User] = []
    var isLoading = false
    var errorMessage: String?
    
    // No @Published needed!
}

struct UserListView: View {
    @State private var viewModel = UserViewModel()
    
    var body: some View {
        // View updates only when accessed properties change
    }
}
```

**❌ DON'T: Use ObservableObject for new code**
```swift
// Legacy pattern - avoid
class OldViewModel: ObservableObject {
    @Published var data: [Item] = []
}
```

### Property Wrapper Rules

| Use Case | Property Wrapper | Example |
|----------|-----------------|---------|
| View-owned state | @State | `@State private var isEditing = false` |
| Two-way binding | @Binding | `@Binding var text: String` |
| Environment values | @Environment | `@Environment(\.dismiss) var dismiss` |
| Observable binding | @Bindable | `@Bindable var user: User` |

---

## 3. Async/Await Patterns

### Task Modifier Usage

**✅ DO: Use task(id:) for reactive data loading**
```swift
struct ContentView: View {
    @State private var viewModel = DataViewModel()
    @State private var searchQuery = ""
    
    var body: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
        }
        .task(id: searchQuery) {
            await viewModel.search(query: searchQuery)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
```

### MainActor Usage

**✅ DO: Mark ViewModels with @MainActor**
```swift
@MainActor
@Observable
class DataViewModel {
    var items: [Item] = []
    
    func loadData() async {
        do {
            items = try await apiService.fetchItems()
        } catch {
            // Error handling
        }
    }
}
```

---

## 4. Code Organization

### File Structure Pattern

```swift
// MediaListView.swift
struct MediaListView: View {
    @State private var viewModel = ViewModel()
    
    var body: some View {
        // Main view implementation
    }
}

// MediaListView+ViewModel.swift
extension MediaListView {
    @Observable
    class ViewModel {
        // ViewModel implementation
    }
}

// MediaListView+Components.swift
extension MediaListView {
    struct RowView: View {
        let item: MediaItem
        
        var body: some View {
            // Row implementation
        }
    }
}
```

### View Size Limits

**RULE: Maximum 10 direct children in ViewBuilder**
```swift
// ❌ BAD: Too many views
var body: some View {
    VStack {
        Text("1")
        Text("2")
        // ... up to Text("11") - COMPILER ERROR
    }
}

// ✅ GOOD: Extract into groups or methods
var body: some View {
    VStack {
        headerSection
        contentSection
        footerSection
    }
}

@ViewBuilder
private var headerSection: some View {
    // Header views
}
```

### Function Length Guidelines
- View body: Maximum 20 lines
- Functions: Maximum 40 lines
- Extract complex logic into computed properties

---

## 5. Navigation Patterns

### Adaptive Navigation Architecture

**RULE: Centralize navigation logic in a single file that adapts to platform and size class**

```swift
// AppNavigation.swift - Single source of truth for navigation
struct AppNavigation: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationModel = NavigationModel()
    
    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                // iPhone or iPad in compact mode
                iPhoneNavigation
            } else {
                // iPad in regular mode
                iPadNavigation
            }
            #elseif os(macOS)
            macOSNavigation
            #endif
        }
        .environment(navigationModel)
    }
    
    // iPhone: TabView or NavigationStack
    @ViewBuilder
    private var iPhoneNavigation: some View {
        if navigationModel.useTabNavigation {
            TabView(selection: $navigationModel.selectedTab) {
                ForEach(NavigationTab.allCases) { tab in
                    NavigationStack(path: $navigationModel.paths[tab, default: NavigationPath()]) {
                        tab.rootView
                            .navigationDestination(for: Route.self) { route in
                                route.destination
                            }
                    }
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
                }
            }
        } else {
            NavigationStack(path: $navigationModel.globalPath) {
                RootView()
                    .navigationDestination(for: Route.self) { route in
                        route.destination
                    }
            }
        }
    }
    
    // iPad: NavigationSplitView with optional inspector
    @ViewBuilder
    private var iPadNavigation: some View {
        NavigationSplitView(
            columnVisibility: $navigationModel.columnVisibility,
            preferredCompactColumn: $navigationModel.preferredCompactColumn
        ) {
            // Sidebar
            SidebarView(selection: $navigationModel.selectedSidebarItem)
                .navigationSplitViewColumnWidth(
                    min: 200,
                    ideal: 250,
                    max: 300
                )
        } content: {
            // Content area
            if let selectedItem = navigationModel.selectedSidebarItem {
                NavigationStack(path: $navigationModel.contentPath) {
                    ContentView(item: selectedItem)
                        .navigationDestination(for: Route.self) { route in
                            route.destination
                        }
                }
            } else {
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "sidebar.left",
                    description: Text("Choose an item from the sidebar to begin")
                )
            }
        } detail: {
            // Detail area
            NavigationStack(path: $navigationModel.detailPath) {
                if let detailItem = navigationModel.selectedDetailItem {
                    DetailView(item: detailItem)
                        .navigationDestination(for: Route.self) { route in
                            route.destination
                        }
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "doc.text",
                        description: Text("Select an item to view details")
                    )
                }
            }
            .inspector(isPresented: $navigationModel.showInspector) {
                InspectorView()
                    .inspectorColumnWidth(
                        min: 200,
                        ideal: 300,
                        max: 400
                    )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // macOS: Similar to iPad but with platform-specific adjustments
    @ViewBuilder
    private var macOSNavigation: some View {
        NavigationSplitView {
            SidebarView(selection: $navigationModel.selectedSidebarItem)
                .navigationSplitViewColumnWidth(250)
        } detail: {
            if let selectedItem = navigationModel.selectedSidebarItem {
                NavigationStack(path: $navigationModel.detailPath) {
                    DetailView(item: selectedItem)
                        .navigationDestination(for: Route.self) { route in
                            route.destination
                        }
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}
```

### Navigation Model

```swift
// NavigationModel.swift
@Observable
class NavigationModel {
    // Navigation state
    var selectedTab: NavigationTab = .home
    var globalPath = NavigationPath()
    var paths: [NavigationTab: NavigationPath] = [:]
    
    // Split view state
    var selectedSidebarItem: SidebarItem?
    var selectedDetailItem: DetailItem?
    var contentPath = NavigationPath()
    var detailPath = NavigationPath()
    
    // UI state
    var columnVisibility = NavigationSplitViewVisibility.automatic
    var preferredCompactColumn = NavigationSplitViewColumn.sidebar
    var showInspector = false
    var useTabNavigation = true
    
    // Navigation methods
    func navigate(to route: Route) {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            globalPath.append(route)
        } else {
            detailPath.append(route)
        }
        #else
        detailPath.append(route)
        #endif
    }
    
    func popToRoot() {
        globalPath.removeLast(globalPath.count)
        contentPath.removeLast(contentPath.count)
        detailPath.removeLast(detailPath.count)
    }
    
    func showDetail(_ item: DetailItem) {
        selectedDetailItem = item
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            columnVisibility = .all
        }
        #endif
    }
}
```

### Route Definition

```swift
// Route.swift
enum Route: Hashable {
    case home
    case profile(User)
    case settings
    case item(Item)
    case search(query: String)
    
    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeView()
        case .profile(let user):
            ProfileView(user: user)
        case .settings:
            SettingsView()
        case .item(let item):
            ItemDetailView(item: item)
        case .search(let query):
            SearchResultsView(query: query)
        }
    }
}

enum NavigationTab: String, CaseIterable, Identifiable {
    case home, explore, favorites, profile
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .favorites: return "Favorites"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .explore: return "magnifyingglass"
        case .favorites: return "heart"
        case .profile: return "person"
        }
    }
    
    @ViewBuilder
    var rootView: some View {
        switch self {
        case .home: HomeView()
        case .explore: ExploreView()
        case .favorites: FavoritesView()
        case .profile: ProfileView()
        }
    }
}
```

### NavigationStack with Type-Safe Routing

```swift
struct ContentView: View {
    @Environment(NavigationModel.self) private var navigationModel
    
    var body: some View {
        List(items) { item in
            Button {
                navigationModel.navigate(to: .item(item))
            } label: {
                ItemRow(item: item)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Content")
    }
}
```

### Adaptive Layout Patterns

```swift
struct ResponsiveView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationModel.self) private var navigationModel
    
    var body: some View {
        if horizontalSizeClass == .compact {
            // Stack navigation for compact layouts
            VStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
            }
        } else {
            // Split view for regular layouts
            HSplitView {
                sidebar
                    .frame(minWidth: 250, idealWidth: 300)
                
                detail
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
```

### Deep Linking Support

```swift
extension NavigationModel {
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }
        
        switch host {
        case "profile":
            if let userId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .profile(User(id: userId)))
            }
        case "item":
            if let itemId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .item(Item(id: itemId)))
            }
        default:
            break
        }
    }
}
```

### Navigation Best Practices

1. **Always use NavigationStack inside TabView**, never the reverse
2. **NavigationSplitView at root level** for iPad/Mac apps
3. **Single navigation model** shared via environment
4. **Type-safe routes** with associated values
5. **Platform-adaptive layouts** using size classes
6. **Preserve navigation state** per tab on iPhone
7. **Use .navigationDestination(for:)** for type-safe navigation
8. **Implement deep linking** through the navigation model
9. **Show inspector on iPad/Mac** for additional details
10. **Use ContentUnavailableView** for empty states

---

## 6. Native Components

### Form Usage

**✅ DO: Use Form for settings and data input**
```swift
struct SettingsView: View {
    @State private var username = ""
    @State private var emailNotifications = true
    @State private var selectedTheme = Theme.system
    @State private var volume = 0.5
    
    var body: some View {
        NavigationStack {
            Form {
                // Text input section
                Section("Profile") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                    
                    LabeledContent("User ID") {
                        Text("u_12345")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Preferences section
                Section("Preferences") {
                    Toggle("Email Notifications", isOn: $emailNotifications)
                    
                    Picker("Theme", selection: $selectedTheme) {
                        Text("System").tag(Theme.system)
                        Text("Light").tag(Theme.light)
                        Text("Dark").tag(Theme.dark)
                    }
                    
                    LabeledContent("Volume") {
                        Slider(value: $volume, in: 0...1)
                    }
                }
                
                // Navigation links
                Section("Account") {
                    NavigationLink("Privacy Settings") {
                        PrivacySettingsView()
                    }
                    
                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                }
                
                // Actions section
                Section {
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .formStyle(.grouped) // iOS 16+
        }
    }
}
```

**Form with Validation**
```swift
struct RegistrationForm: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email, password, confirmPassword
    }
    
    var isFormValid: Bool {
        !email.isEmpty && 
        password.count >= 8 && 
        password == confirmPassword && 
        agreeToTerms
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                } header: {
                    Text("Account Information")
                } footer: {
                    if password.count > 0 && password.count < 8 {
                        Text("Password must be at least 8 characters")
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Toggle(isOn: $agreeToTerms) {
                        Text("I agree to the Terms of Service")
                    }
                }
                
                Section {
                    Button("Create Account") {
                        createAccount()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Sign Up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss)
                }
            }
        }
    }
}
```

**Form Best Practices**
```swift
struct DataEntryForm: View {
    @State private var formData = FormData()
    
    var body: some View {
        Form {
            // Group related fields
            Section("Personal Information") {
                TextField("First Name", text: $formData.firstName)
                    .textContentType(.givenName)
                
                TextField("Last Name", text: $formData.lastName)
                    .textContentType(.familyName)
                
                DatePicker(
                    "Date of Birth",
                    selection: $formData.dateOfBirth,
                    displayedComponents: .date
                )
            }
            
            // Use appropriate controls
            Section("Preferences") {
                // For 2-5 options: Picker
                Picker("Notification Frequency", selection: $formData.frequency) {
                    Text("Never").tag(Frequency.never)
                    Text("Daily").tag(Frequency.daily)
                    Text("Weekly").tag(Frequency.weekly)
                }
                
                // For many options: NavigationLink
                NavigationLink("Country") {
                    CountrySelectionView(selection: $formData.country)
                }
                
                // For binary choices: Toggle
                Toggle("Marketing Emails", isOn: $formData.marketingEmails)
            }
            
            // Clear actions
            Section {
                Button("Save", action: save)
                    .disabled(!formData.isValid)
                
                Button("Reset", role: .destructive, action: reset)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
```

### Form vs List Usage

**✅ DO: Use Form for settings and input**
```swift
Form {
    Section("Profile") {
        TextField("Name", text: $name)
        DatePicker("Birthday", selection: $date, displayedComponents: .date)
    }
    
    Section("Preferences") {
        Toggle("Notifications", isOn: $notifications)
        Picker("Theme", selection: $theme) {
            ForEach(Theme.allCases) { theme in
                Text(theme.name).tag(theme)
            }
        }
    }
}
```

**✅ DO: Use List for data display**
```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
    }
    .onDelete(perform: delete)
    .onMove(perform: move)
}
.listStyle(.insetGrouped)
.searchable(text: $searchText)
.refreshable {
    await refresh()
}
```

### Menu Usage

**✅ DO: Use Menu to reduce toolbar clutter**
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button("Sort by Name", action: sortByName)
            Button("Sort by Date", action: sortByDate)
            Divider()
            Button("Filter", action: showFilter)
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }
}
```

### ConfirmationDialog

```swift
.confirmationDialog(
    "Delete Item?",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        deleteItem()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This action cannot be undone.")
}
```

### ContentUnavailableView for Empty States

**✅ DO: Use ContentUnavailableView for empty states**
```swift
// Good: Standard empty state
struct MediaListView: View {
    let mediaAssets: [MediaAsset]
    
    var body: some View {
        if mediaAssets.isEmpty {
            ContentUnavailableView(
                "No Media Assets",
                systemImage: "photo.on.rectangle",
                description: Text("Upload your first video or image to get started")
            )
        } else {
            List(mediaAssets) { asset in
                MediaAssetRow(asset: asset)
            }
        }
    }
}

// Good: Search results empty state
struct SearchResultsView: View {
    let query: String
    let results: [SearchResult]
    
    var body: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(results) { result in
                SearchResultRow(result: result)
            }
        }
    }
}

// Good: Custom action with button
struct TodoListView: View {
    @State private var todos: [Todo] = []
    
    var body: some View {
        if todos.isEmpty {
            ContentUnavailableView {
                Label("No Tasks", systemImage: "checklist")
            } description: {
                Text("Create your first task to get organized")
            } actions: {
                Button("Add Task") {
                    addNewTask()
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            List(todos) { todo in
                TodoRow(todo: todo)
            }
        }
    }
}
```

**❌ DON'T: Create custom empty state views**
```swift
// Bad: Manual empty state
VStack(spacing: 16) {
    Image(systemName: "photo.on.rectangle")
        .font(.largeTitle)
        .foregroundColor(.secondary)
    
    Text("No Media Assets")
        .font(.title2)
        .fontWeight(.semibold)
    
    Text("Upload your first video or image to get started")
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
}
.padding()

// Bad: Custom styling that doesn't match system
VStack {
    Image(systemName: "magnifyingglass")
        .foregroundColor(.blue)
    Text("No Results")
        .font(.custom("MyFont", size: 20))
}
```

**Built-in ContentUnavailableView variants:**
```swift
// Search empty state
ContentUnavailableView.search

// Search with specific text
ContentUnavailableView.search(text: searchQuery)

// Loading state (iOS 17+)
ContentUnavailableView {
    Label("Loading", systemImage: "arrow.clockwise")
} description: {
    Text("Please wait while we load your data")
}

// Error state
ContentUnavailableView {
    Label("Connection Error", systemImage: "wifi.slash")
} description: {
    Text("Check your internet connection and try again")
} actions: {
    Button("Retry") {
        retry()
    }
}
```

**ContentUnavailableView Best Practices:**
- Use system-provided variants when possible (`.search`)
- Keep descriptions concise and helpful
- Include actionable buttons when appropriate
- Use semantic SF Symbols that match the context
- Avoid custom styling - let the system handle appearance
- Always provide meaningful descriptions for accessibility
- Consider different states: empty, loading, error, no search results

---

## 7. ScrollView and Modern APIs

### Avoiding GeometryReader

**❌ DON'T: Use GeometryReader unnecessarily**
```swift
// Bad
GeometryReader { geometry in
    ScrollView {
        content
            .frame(width: geometry.size.width)
    }
}
```

**✅ DO: Use modern ScrollView APIs**
```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
                .containerRelativeFrame(.horizontal)
        }
    }
    .scrollTargetLayout()
}
.contentMargins(16)
.onScrollGeometryChange(for: Bool.self) { geometry in
    geometry.contentOffset.y > 100
} action: { oldValue, newValue in
    showScrollToTop = newValue
}
```

### ScrollView Position and Phase

```swift
struct ModernScrollView: View {
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollPhase: ScrollPhase = .idle
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<100) { i in
                    Text("Item \(i)")
                        .id(i)
                        .frame(height: 50)
                }
            }
        }
        .scrollPosition($scrollPosition)
        .onScrollPhaseChange { oldPhase, newPhase in
            scrollPhase = newPhase
        }
    }
}
```

### Safe Area Insets for Bottom/Top Bars

**✅ DO: Use .safeAreaInset() for bottom/top bar content**
```swift
// Good: Using safeAreaInset for bottom bars
struct ScrollableViewWithBottomBar: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBarContent()
        }
    }
}

// Good: Using safeAreaInset for top bars
struct ScrollableViewWithTopBar: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBarContent()
        }
    }
}
```

**❌ DON'T: Use VStack or overlay for bar content**
```swift
// Bad: Using VStack creates layout issues
VStack {
    ScrollView {
        // Content
    }
    BottomBarContent()
}

// Bad: Using overlay doesn't respect safe areas properly
ScrollView {
    // Content
}
.overlay(alignment: .bottom) {
    BottomBarContent()
}
```

**Benefits of .safeAreaInset():**
- Automatically adjusts scroll content to account for bar space
- Respects safe area boundaries
- Provides proper scrolling behavior with bars
- Maintains consistent spacing and padding

---

## 8. Sheet Presentation

### Modern Sheet APIs

```swift
enum SheetContent: Identifiable {
    case addItem
    case editItem(Item)
    case settings
    
    var id: String {
        switch self {
        case .addItem: return "add"
        case .editItem(let item): return "edit-\(item.id)"
        case .settings: return "settings"
        }
    }
}

struct ContentView: View {
    @State private var sheet: SheetContent?
    
    var body: some View {
        Button("Show Sheet") {
            sheet = .addItem
        }
        .sheet(item: $sheet) { content in
            SheetView(content: content)
                .presentationDetents([.height(250), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
        }
    }
}
```

---

## 9. Toolbar Management

### Semantic Toolbar Placement

```swift
.toolbar {
    // Primary action - most important
    ToolbarItem(placement: .primaryAction) {
        Button("Save", action: save)
    }
    
    // Confirmation actions
    ToolbarItem(placement: .confirmationAction) {
        Button("Done", action: done)
    }
    
    // Cancellation actions
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", action: cancel)
    }
    
    // Destructive actions
    ToolbarItem(placement: .destructiveAction) {
        Button("Delete", role: .destructive, action: delete)
    }
    
    // Grouped items
    ToolbarItemGroup(placement: .secondaryAction) {
        Button("Share", systemImage: "square.and.arrow.up", action: share)
        Button("Print", systemImage: "printer", action: print)
    }
}
```

---

## 10. MVVM Architecture with Service Pattern

> **📖 For comprehensive MVVM documentation, see [swiftui-mvvm.md](swiftui-mvvm.md)**

### Quick Reference

**Modern ViewModel Pattern**
```swift
@MainActor
@Observable
final class ProductListViewModel {
    private let productService: ProductDataService
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    init(productService: ProductDataService) {
        self.productService = productService
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await productService.loadProducts()
        } catch {
            errorMessage = error.localizedDescription
            products = []
        }
        
        isLoading = false
    }
}
```

**Service Protocol Foundation**
```swift
protocol ProductDataService {
    func loadProducts() async throws -> [Product]
}

final class ProductionProductService: ProductDataService {
    func loadProducts() async throws -> [Product] {
        // Real API/Database implementation
    }
}

final class MockProductService: ProductDataService {
    var productsToReturn: [Product]
    var shouldThrowError: Bool
    var delay: TimeInterval
    
    init(products: [Product] = [], shouldThrowError: Bool = false, delay: TimeInterval = 0) {
        self.productsToReturn = products
        self.shouldThrowError = shouldThrowError
        self.delay = delay
    }
    
    func loadProducts() async throws -> [Product] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw URLError(.notConnectedToInternet)
        }
        
        return productsToReturn
    }
}
```

### Key Principles

1. **Use `@Observable` + `@MainActor`** for all ViewModels
2. **Inject dependencies** through View init with defaults
3. **Abstract services** with protocols for testing
4. **Handle all states** (loading, error, empty, success)
5. **Use `private(set)`** for ViewModel state properties
6. **Create comprehensive mocks** for testing and previews

See [swiftui-mvvm.md](swiftui-mvvm.md) for detailed patterns, examples, and best practices.

---

## 11. Preview Macros

### Comprehensive Preview Setup

```swift
#Preview("Light Mode") {
    ContentView()
        .environment(\.locale, .init(identifier: "en"))
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("iPad", traits: .fixedLayout(width: 768, height: 1024)) {
    ContentView()
}

// Interactive preview with state
#Preview("Interactive") {
    @Previewable @State var count = 0
    
    CounterView(count: $count)
}
```

---

## 12. Performance Optimization

### View Update Optimization

```swift
// ✅ GOOD: Minimal view updates
@Observable
class OptimizedViewModel {
    var visibleItems: [Item] = []
    private var allItems: [Item] = []
    
    func filter(by query: String) {
        visibleItems = allItems.filter { $0.matches(query) }
    }
}

// Debug view updates
let _ = Self._printChanges()
```

### ViewThatFits Usage

```swift
ViewThatFits {
    // Try horizontal layout first
    HStack {
        Image(systemName: "star")
        Text("Premium Feature")
    }
    
    // Fall back to vertical if needed
    VStack {
        Image(systemName: "star")
        Text("Premium")
    }
}
```

---

## 13. SwiftData Integration

### Model Definition

```swift
import SwiftData

@Model
final class Task {
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: Priority
    
    @Relationship(deleteRule: .cascade)
    var subtasks: [Subtask] = []
    
    init(title: String, priority: Priority = .medium) {
        self.title = title
        self.isCompleted = false
        self.priority = priority
    }
}
```

### Query Usage

```swift
struct TaskListView: View {
    @Query(
        filter: #Predicate<Task> { !$0.isCompleted },
        sort: [SortDescriptor(\.dueDate), SortDescriptor(\.priority)]
    ) private var tasks: [Task]
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List(tasks) { task in
            TaskRow(task: task)
        }
    }
}
```

---

## 14. Keyboard and Search

### Searchable Implementation

```swift
struct SearchableListView: View {
    @State private var searchText = ""
    @State private var searchScope = SearchScope.all
    
    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                ItemRow(item: item)
            }
            .searchable(text: $searchText, prompt: "Search items")
            .searchScopes($searchScope) {
                Text("All").tag(SearchScope.all)
                Text("Recent").tag(SearchScope.recent)
                Text("Favorites").tag(SearchScope.favorites)
            }
            .onSubmit(of: .search) {
                performSearch()
            }
        }
    }
}
```

### Keyboard Management

```swift
struct FormView: View {
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, email, password
    }
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
                .focused($focusedField, equals: .username)
            
            TextField("Email", text: $email)
                .focused($focusedField, equals: .email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
            
            SecureField("Password", text: $password)
                .focused($focusedField, equals: .password)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous") { moveToPreviousField() }
                Button("Next") { moveToNextField() }
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }
}
```

---

## 15. Design System

### Color Usage

**✅ DO: Use semantic colors**
```swift
Text("Title")
    .foregroundStyle(.primary)

Text("Subtitle")
    .foregroundStyle(.secondary)

VStack {
    content
}
.background(.regularMaterial)
```

**❌ DON'T: Use hard-coded colors**
```swift
// Bad
Text("Title")
    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
```

### Typography

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Large Title")
        .font(.largeTitle)
    
    Text("Title")
        .font(.title)
    
    Text("Headline")
        .font(.headline)
    
    Text("Body")
        .font(.body)
    
    Text("Caption")
        .font(.caption)
}
```

### Spacing Guidelines

**✅ DO: Use default padding values when possible**
```swift
// PREFERRED: Use system defaults
VStack {
    content
}
.padding() // System default: dynamic based on context

// Stack spacing defaults
VStack { } // Default spacing
HStack { } // Default spacing

// System semantic spacing
.padding(.horizontal)
.padding(.vertical)
.padding(.leading)
.padding(.trailing)
```

**✅ DO: Use spacing constants for custom values**
```swift
// When custom spacing is needed, ALWAYS use constants
enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

// Usage
VStack(spacing: Spacing.large) {
    header
    content
}
.padding(.top, Spacing.medium)
.padding(.horizontal, Spacing.small)
```

**❌ DON'T: Hardcode spacing values**
```swift
// NEVER DO THIS
.padding(.top, 8) // Bad!
.padding(.horizontal, 16) // Bad!
VStack(spacing: 12) { } // Bad!

// ALWAYS use either:
.padding(.top, Spacing.small) // Good - using constant
.padding(.top) // Good - using system default
```

**Spacing Rules:**
1. First choice: Use system defaults (`.padding()`)
2. Second choice: Use spacing constants (`.padding(.top, Spacing.medium)`)
3. Never: Hardcode values (`.padding(.top, 8)`)

### Button Styling

**✅ DO: Use system button styles and roles**
```swift
// Primary actions with button roles
Button("Get Started", role: .none) { }
    .buttonStyle(.borderedProminent)

// Destructive actions
Button("Delete", role: .destructive) { }
    .buttonStyle(.borderedProminent)

// Cancel actions
Button("Cancel", role: .cancel) { }
    .buttonStyle(.bordered)

// Secondary actions  
Button("Learn More") { }
    .buttonStyle(.bordered)

// Tertiary actions
Button("Skip") { }
    .buttonStyle(.plain)

// Customization with system styles
Button("Custom Style") { }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .tint(.purple)
    .controlSize(.large)
```

**Custom Button Styles with Static Member Lookup**
```swift
// Create custom button style when needed
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .bold()
            .foregroundStyle(.white)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}

// Make it discoverable with static member lookup
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}

// Usage - clean and discoverable
Button("Save") { }
    .buttonStyle(.primary)
```

**Advanced: PrimitiveButtonStyle for Custom Interactions**
```swift
// Double tap support with custom interactions
struct DoubleTapButtonStyle: PrimitiveButtonStyle {
    let doubleTapAction: () -> Void
    @GestureState private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .opacity(isPressed ? 0.75 : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, isPressed, _ in
                        isPressed = true
                    }
            )
            .onTapGesture(count: 1, perform: configuration.trigger)
            .onTapGesture(count: 2, perform: doubleTapAction)
    }
}

// Static member with parameter
extension PrimitiveButtonStyle where Self == DoubleTapButtonStyle {
    static func doubleTap(action: @escaping () -> Void) -> DoubleTapButtonStyle {
        DoubleTapButtonStyle(doubleTapAction: action)
    }
}

// Usage
Button("Tap or Double Tap") {
    print("Single tap")
}
.buttonStyle(.doubleTap {
    print("Double tap")
})
```

**Button Style Decision Guide**
| Use Case | Style | Example |
|----------|-------|---------|
| Primary CTA | `.borderedProminent` | Get Started, Save |
| Secondary action | `.bordered` | Learn More, Options |
| Tertiary/text link | `.plain` | Skip, Cancel |
| Destructive | `.borderedProminent` + `.destructive` role | Delete, Remove |
| Custom brand | Custom ButtonStyle | Brand-specific designs |

---

## 16. Multi-Platform Support

### Platform-Adaptive Views

```swift
struct AdaptiveView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            CompactLayout()
        } else {
            RegularLayout()
        }
        #elseif os(macOS)
        MacLayout()
        #endif
    }
}
```

### macOS-Specific Features

**Window Management**
```swift
struct MacWindowView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack {
            Button("Open Preferences") {
                openWindow(id: "preferences")
            }
            
            Button("Open Document") {
                openWindow(value: Document(id: "123"))
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        .windowResizability(.contentSize)
        #endif
    }
}

// Window configuration
WindowGroup("Document Viewer", for: Document.ID.self) { $documentID in
    if let documentID {
        DocumentView(documentID: documentID)
    }
}
#if os(macOS)
.windowStyle(.titleBar)
.windowToolbarStyle(.unified)
.defaultSize(width: 800, height: 600)
#endif
```

**Menu Bar and Commands**
```swift
struct AppCommands: Commands {
    @CommandsBuilder
    var body: some Commands {
        // Replace standard menus
        CommandGroup(replacing: .newItem) {
            Button("New Document") {
                createNewDocument()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        // Custom menu
        CommandMenu("Tools") {
            Button("Process") {
                processData()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            
            Divider()
            
            Menu("Export") {
                Button("Export as PDF") { exportPDF() }
                Button("Export as CSV") { exportCSV() }
            }
        }
        
        // Sidebar commands
        SidebarCommands()
        
        // Toolbar commands
        ToolbarCommands()
    }
}
```

**AppKit Integration When Needed**
```swift
#if os(macOS)
import AppKit

// NSViewRepresentable for complex text editing
struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.attributedString() != attributedText {
            nsView.textStorage?.setAttributedString(attributedText)
        }
    }
}

// NSHostingView for embedding SwiftUI in AppKit
class CustomWindowController: NSWindowController {
    convenience init<Content: View>(rootView: Content) {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 400, height: 300))
        self.init(window: window)
    }
}
#endif
```

### Platform-Specific Modifiers

```swift
extension View {
    func platformModifiers() -> some View {
        self
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            #elseif os(macOS)
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        refresh()
                    }
                }
            }
            #endif
    }
}
```

### Shared Code Best Practices

```swift
// Models - 100% shared
struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
}

// ViewModels - 95% shared
@Observable
class UserViewModel {
    var users: [User] = []
    
    func loadUsers() async {
        // Shared logic
    }
    
    #if os(macOS)
    func exportToCSV() {
        // macOS-specific export
    }
    #endif
}

// Views - 80% shared with platform adaptations
struct UserListView: View {
    @State private var viewModel = UserViewModel()
    
    var body: some View {
        List(viewModel.users) { user in
            UserRow(user: user)
        }
        .listStyle(listStyle)
        .task {
            await viewModel.loadUsers()
        }
    }
    
    private var listStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .sidebar
        #endif
    }
}
```

### Platform Detection Helpers

```swift
enum Platform {
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isMac: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
}

// Usage
struct ContentView: View {
    var body: some View {
        if Platform.isMac {
            MacContentView()
        } else if Platform.isIPad {
            IPadContentView()
        } else {
            IPhoneContentView()
        }
    }
}
```

---

## 17. Accessibility

### VoiceOver Support

```swift
struct AccessibleButton: View {
    let item: Item
    
    var body: some View {
        Button {
            toggleFavorite()
        } label: {
            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
        }
        .accessibilityLabel(
            item.isFavorite ? "Remove from favorites" : "Add to favorites"
        )
        .accessibilityHint("Double tap to toggle favorite status for \(item.name)")
        .accessibilityIdentifier("favoriteButton")
    }
}
```

### Dynamic Type

```swift
struct ScalableView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        if dynamicTypeSize >= .accessibility1 {
            // Vertical layout for large text
            VStack(alignment: .leading) {
                icon
                text
            }
        } else {
            // Horizontal layout for regular text
            HStack {
                icon
                text
            }
        }
    }
}
```

---

## 18. Localization

### String Catalogs

```swift
// Use String Catalogs for automatic extraction
Text("Welcome")
    // Automatically extracted to Localizable.xcstrings

// With interpolation
Text("Hello, \(userName)")

// Pluralization
Text("You have \(count) items", comment: "Item count")
```

### Formatted Values

```swift
// Numbers
Text(price, format: .currency(code: "USD"))

// Dates
Text(date, format: .dateTime.day().month().year())

// Measurements
Text(distance, format: .measurement(width: .abbreviated))
```

---

## 19. Error Handling

### Centralized Error Management

```swift
@Observable
class ErrorHandler {
    var currentError: AppError?
    
    func handle(_ error: Error) {
        if let appError = error as? AppError {
            currentError = appError
        } else {
            currentError = .unknown(error)
        }
    }
}

// Usage in root view
.alert(item: $errorHandler.currentError) { error in
    Alert(
        title: Text(error.title),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
    )
}
```

---

## 20. Testing Strategies

### Swift Testing Framework

**✅ DO: Use Swift Testing for all new tests**
```swift
import Testing
import SwiftUI
@testable import MyApp

struct UserViewModelTests {
    @Test
    func loadUsers() async throws {
        // Arrange
        let mockService = MockUserService()
        let viewModel = UserViewModel(service: mockService)
        
        // Act
        await viewModel.loadUsers()
        
        // Assert
        #expect(viewModel.users.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("User filtering works correctly")
    func filterUsers() async {
        let viewModel = UserViewModel()
        viewModel.users = User.mockUsers
        
        viewModel.filterByActive()
        
        #expect(viewModel.filteredUsers.allSatisfy { $0.isActive })
    }
}
```

### Parameterized Tests

```swift
struct ValidationTests {
    @Test(
        "Email validation",
        arguments: [
            ("test@example.com", true),
            ("invalid.email", false),
            ("user@", false),
            ("@domain.com", false),
            ("user@domain.com", true)
        ]
    )
    func validateEmail(email: String, isValid: Bool) {
        #expect(EmailValidator.validate(email) == isValid)
    }
}
```

### Testing Async Code

```swift
struct NetworkTests {
    @Test
    func fetchDataWithTimeout() async throws {
        let service = DataService()
        
        // Use withTimeout for async operations
        try await withTimeout(seconds: 5) {
            let data = try await service.fetchData()
            #expect(data.count > 0)
        }
    }
    
    @Test
    func handleNetworkError() async {
        let service = DataService(shouldFail: true)
        
        await #expect(throws: NetworkError.self) {
            try await service.fetchData()
        }
    }
}
```

### Testing ViewModels

```swift
@MainActor
struct ProductViewModelTests {
    @Test("Loading state transitions correctly")
    func loadingStates() async {
        let viewModel = ProductViewModel()
        
        #expect(!viewModel.isLoading)
        
        let task = Task {
            await viewModel.loadProducts()
        }
        
        // Check loading state immediately
        #expect(viewModel.isLoading)
        
        await task.value
        
        #expect(!viewModel.isLoading)
        #expect(viewModel.products.count > 0)
    }
}
```

### Testing with Dependencies

```swift
struct DependencyTests {
    struct TestContext {
        let apiClient: MockAPIClient
        let database: MockDatabase
        let viewModel: ContentViewModel
        
        init() {
            self.apiClient = MockAPIClient()
            self.database = MockDatabase()
            self.viewModel = ContentViewModel(
                apiClient: apiClient,
                database: database
            )
        }
    }
    
    @Test
    func syncData() async throws {
        let context = TestContext()
        
        // Configure mocks
        context.apiClient.mockResponse = .success([Item.mock])
        
        await context.viewModel.sync()
        
        #expect(context.database.savedItems.count == 1)
        #expect(context.viewModel.isSynced)
    }
}
```

### UI Testing with Swift Testing

```swift
import Testing
import SwiftUI
import ViewInspector

struct ViewTests {
    @Test
    func buttonUpdatesCounter() throws {
        let view = CounterView()
        
        let button = try view.inspect().button()
        try button.tap()
        
        let text = try view.inspect().text()
        #expect(try text.string() == "Count: 1")
    }
    
    @Test("Navigation presents correct view")
    func navigationTest() throws {
        let view = NavigationView()
        
        let navLink = try view.inspect().navigationLink()
        try navLink.activate()
        
        #expect(view.isShowingDetail)
    }
}
```

### Snapshot Testing with Swift Testing

```swift
import Testing
import SnapshotTesting

struct SnapshotTests {
    @Test(
        "Component snapshots",
        arguments: [
            ("Light", UIUserInterfaceStyle.light),
            ("Dark", UIUserInterfaceStyle.dark)
        ]
    )
    func componentSnapshots(name: String, style: UIUserInterfaceStyle) {
        let view = ComponentView()
            .preferredColorScheme(style == .dark ? .dark : .light)
        
        assertSnapshot(
            matching: view,
            as: .image(traits: UITraitCollection(userInterfaceStyle: style)),
            named: name
        )
    }
    
    @Test("Responsive layouts")
    func responsiveSnapshots() {
        let view = ResponsiveView()
        
        // Test different device sizes
        let devices: [(String, ViewImageConfig)] = [
            ("iPhone15Pro", .iPhone15Pro),
            ("iPadPro", .iPadPro12_9),
            ("Mac", .fixed(width: 1200, height: 800))
        ]
        
        for (name, config) in devices {
            assertSnapshot(
                matching: view,
                as: .image(layout: .device(config: config)),
                named: name
            )
        }
    }
}
```

### Test Organization

```swift
// Organize tests by feature
@Suite("User Management")
struct UserManagementTests {
    @Suite("Authentication")
    struct AuthTests {
        @Test func login() async { /* ... */ }
        @Test func logout() async { /* ... */ }
    }
    
    @Suite("Profile")
    struct ProfileTests {
        @Test func updateProfile() async { /* ... */ }
        @Test func deleteAccount() async { /* ... */ }
    }
}
```

### Testing Best Practices

```swift
// Use tags for test organization
@Test(.tags(.critical, .authentication))
func criticalAuthFlow() async {
    // Critical path testing
}

@Test(.disabled("Waiting for API implementation"))
func futureFeature() {
    // Test disabled until ready
}

@Test(.timeLimit(.minutes(1)))
func performanceTest() async {
    // Test with time limit
}
```

---

## 21. Animation Best Practices

### Animation Guidelines

**✅ DO: Use explicit animations**
```swift
struct AnimatedView: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Button("Toggle") {
                isExpanded.toggle()
            }
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
                .frame(height: isExpanded ? 200 : 100)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isExpanded)
        }
    }
}
```

**❌ DON'T: Use implicit animations**
```swift
// AVOID: Can cause unexpected animations
.animation(.spring()) // Deprecated
```

### Transaction Control
```swift
Button("No Animation") {
    withTransaction(Transaction(animation: nil)) {
        isExpanded.toggle()
    }
}

Button("Custom Animation") {
    withAnimation(.bouncy(duration: 0.5)) {
        isExpanded.toggle()
    }
}
```

---

## 22. Environment Values and Preferences

### Custom Environment Values
```swift
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.system
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// Usage
struct ThemedView: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        Text("Themed")
            .foregroundStyle(theme.primaryColor)
    }
}
```

### Preference Keys for Child-to-Parent Communication
```swift
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ChildView: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
}

struct ParentView: View {
    @State private var childSize: CGSize = .zero
    
    var body: some View {
        ChildView()
            .onPreferenceChange(SizePreferenceKey.self) { size in
                childSize = size
            }
    }
}
```

---

## 23. Focus Management

### FocusState Best Practices
```swift
struct LoginForm: View {
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case username, password
    }
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
            
            SecureField("Password", text: $password)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    login()
                }
        }
        .onAppear {
            focusedField = .username
        }
    }
}
```

---

## 24. State Restoration

### Scene Storage
```swift
struct ContentView: View {
    @SceneStorage("selectedTab") private var selectedTab = 0
    @SceneStorage("searchText") private var searchText = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView(searchText: $searchText)
                .tag(0)
            
            FavoritesView()
                .tag(1)
        }
    }
}
```

### App Storage
```swift
struct SettingsView: View {
    @AppStorage("username") private var username = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("selectedTheme") private var selectedTheme = Theme.system.rawValue
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
        }
    }
}
```

---

## 25. Gesture Best Practices

### Composing Gestures
```swift
struct InteractiveCard: View {
    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.blue)
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

---

## 26. Image Loading and Caching

### AsyncImage Best Practices
```swift
struct OptimizedImageView: View {
    let imageURL: URL
    
    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 100, height: 100)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            @unknown default:
                EmptyView()
            }
        }
    }
}
```

---

## 27. Custom Transitions

### Creating Reusable Transitions
```swift
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// Usage
if showDetail {
    DetailView()
        .transition(.slideAndFade)
}
```

---

## 28. Memory Management

### Avoiding Retain Cycles
```swift
@MainActor
@Observable
class DataManager {
    var items: [Item] = []
    private var cancellables = Set<AnyCancellable>()
    
    func startObserving() {
        // Use weak self to avoid retain cycles
        NotificationCenter.default
            .publisher(for: .dataDidChange)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
}
```

---

## 29. Conditional View Modifiers

### ViewModifier Pattern
```swift
extension View {
    @ViewBuilder
    func redacted(if condition: Bool) -> some View {
        if condition {
            self.redacted(reason: .placeholder)
        } else {
            self
        }
    }
    
    func onTapGestureIf(_ condition: Bool, perform action: @escaping () -> Void) -> some View {
        if condition {
            self.onTapGesture(perform: action)
        } else {
            self
        }
    }
}

// Usage
Text("Content")
    .redacted(if: isLoading)
    .onTapGestureIf(!isLoading) {
        loadMore()
    }
```

---

## 30. Debug Helpers

### Development Tools
```swift
extension View {
    func debugBorder(_ color: Color = .red, width: CGFloat = 1) -> some View {
        #if DEBUG
        self.border(color, width: width)
        #else
        self
        #endif
    }
    
    func debugPrint(_ message: String) -> some View {
        #if DEBUG
        let _ = print("🔍 \(message)")
        #endif
        return self
    }
    
    func debugModifier<T: View>(@ViewBuilder _ modifier: (Self) -> T) -> some View {
        #if DEBUG
        modifier(self)
        #else
        self
        #endif
    }
}
```

---

## 31. macOS Development Best Practices

### Window Management

**Multiple Windows Support**
```swift
@main
struct MyApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 700)
        
        // Document windows
        DocumentGroup(newDocument: MyDocument()) { file in
            DocumentView(document: file.$document)
        }
        
        // Auxiliary windows
        Window("Activity Monitor", id: "activity") {
            ActivityView()
                .frame(width: 400, height: 600)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}
```

**Window Styling**
```swift
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .background(VisualEffectBlur())
        .onAppear {
            // Set window properties
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            }
        }
        #endif
    }
}
```

### Keyboard Shortcuts

```swift
struct MacKeyboardView: View {
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack {
            SearchField()
                .focused($isSearchFocused)
            
            ContentArea()
        }
        .background {
            // Global keyboard shortcuts
            Color.clear
                .onKeyPress(.return, modifiers: .command) {
                    performAction()
                    return .handled
                }
                .onKeyPress(.escape) {
                    dismiss()
                    return .handled
                }
                .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                    navigateList(direction: press.key)
                    return .handled
                }
        }
        .focusable()
        .focusEffectDisabled()
    }
}
```

### macOS Controls

**Native Search Field**
```swift
struct MacSearchBar: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
```

**Toolbar Customization**
```swift
struct MacToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button("New", systemImage: "plus") {
                createNew()
            }
            .help("Create New Item (⌘N)")
        }
        
        ToolbarItemGroup(placement: .principal) {
            Picker("View", selection: $viewMode) {
                Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
            }
            .pickerStyle(.segmented)
            .help("Change View Mode")
        }
    }
}
```

### File Management

**Document-Based Apps**
```swift
struct MyDocument: FileDocument {
    static var readableContentTypes = [UTType.json]
    var content: DocumentContent
    
    init(content: DocumentContent = DocumentContent()) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = try JSONDecoder().decode(DocumentContent.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(content)
        return FileWrapper(regularFileWithContents: data)
    }
}
```

**File Import/Export**
```swift
struct FileOperationsView: View {
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var document = MyDocument()
    
    var body: some View {
        VStack {
            Button("Import") {
                showImporter = true
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            
            Button("Export") {
                showExporter = true
            }
            .fileExporter(
                isPresented: $showExporter,
                document: document,
                contentType: .json,
                defaultFilename: "Export"
            ) { result in
                handleFileExport(result)
            }
        }
    }
}
```

### Performance Optimizations

**Table Views for Large Data**
```swift
struct DataTableView: View {
    @State private var items: [DataItem] = []
    @State private var sortOrder = [KeyPathComparator(\DataItem.name)]
    @State private var selection: Set<DataItem.ID> = []
    
    var body: some View {
        Table(items, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
                .width(min: 100, ideal: 200)
            
            TableColumn("Date", value: \.date) { item in
                Text(item.date, format: .dateTime)
            }
            .width(100)
            
            TableColumn("Status", value: \.status) { item in
                StatusBadge(status: item.status)
            }
            .width(80)
        }
        .contextMenu(forSelectionType: DataItem.ID.self) { selection in
            contextMenuItems(for: selection)
        }
    }
}
```

### macOS Best Practices Summary

1. **Always provide keyboard shortcuts** for common actions
2. **Use native window styles** (.titleBar, .hiddenTitleBar)
3. **Implement proper menu bar** with Commands
4. **Support multiple windows** for different tasks
5. **Use Table instead of List** for data-heavy views
6. **Integrate with system features** (Services, Quick Look)
7. **Respect macOS conventions** (traffic lights, toolbar placement)
8. **Test with keyboard-only navigation**
9. **Support drag and drop** between apps
10. **Use VisualEffectView** for proper material backgrounds

---

## 32. Advanced SwiftUI Patterns

### Conditional View Modifiers

**✅ DO: Use proper conditional view modifiers**
```swift
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
}

// Usage
Text("Hello")
    .if(isHighlighted) { view in
        view.background(Color.yellow)
    }
    .if(isSelected,
        if: { $0.foregroundColor(.white) },
        else: { $0.foregroundColor(.primary) }
    )
```

### State Management Rules

**✅ DO: Use @State for view-owned data**
```swift
struct ParentView: View {
    @State private var isExpanded = false
    @State private var selectedItem: Item?
    
    var body: some View {
        VStack {
            ExpandableSection(isExpanded: $isExpanded)
            ItemPicker(selectedItem: $selectedItem)
        }
    }
}
```

**✅ DO: Use @Binding for shared state**
```swift
struct ChildView: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(isExpanded ? "Collapse" : "Expand") {
            isExpanded.toggle()
        }
    }
}
```

**❌ DON'T: Use @State for shared data**
```swift
struct ChildView: View {
    @State private var isExpanded = false // Bad: Creates separate state
    
    var body: some View {
        Button("Toggle") {
            isExpanded.toggle() // Only affects this view
        }
    }
}
```

### View Performance Rules

**✅ DO: Use @ViewBuilder functions instead of computed properties**
```swift
struct ContentView: View {
    var body: some View {
        VStack {
            headerView()
            contentView()
            footerView()
        }
    }
    
    @ViewBuilder
    private func headerView() -> some View {
        Text("Header")
            .font(.title)
    }
    
    @ViewBuilder
    private func contentView() -> some View {
        Text("Content")
    }
    
    @ViewBuilder
    private func footerView() -> some View {
        Text("Footer")
    }
}
```

**❌ DON'T: Create complex computed properties**
```swift
struct ContentView: View {
    // Bad: Creates view every time body is called
    private var headerView: some View {
        VStack {
            Text("Header")
            Image(systemName: "star")
        }
    }
    
    var body: some View {
        VStack {
            headerView // Recreated on every body call
        }
    }
}
```

### Modern Button Styles

**✅ DO: Use modern button configurations**
```swift
struct ModernButtons: View {
    var body: some View {
        VStack(spacing: 12) {
            Button("Primary Action") {
                // action
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            
            Button("Secondary Action") {
                // action
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.regular)
            
            Button("Destructive Action") {
                // action
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
```

### List Performance Rules

**✅ DO: Use LazyVStack for large datasets**
```swift
struct PerformantList: View {
    let items: [Item]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ItemRow(item: item)
                        .padding(.horizontal)
                }
            }
        }
        .scrollTargetLayout()
    }
}
```

**❌ DON'T: Use VStack for large datasets**
```swift
struct SlowList: View {
    let items: [Item]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) { // Creates all views at once
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
        }
    }
}
```

### SwiftUI 6.0 @Previewable

**✅ DO: Use @Previewable for preview state**
```swift
#Preview("Interactive Sheet") {
    @Previewable @State var isPresented = false
    @Previewable @State var selectedItem: Item? = nil
    
    ContentView()
        .sheet(isPresented: $isPresented) {
            SheetContent(selectedItem: selectedItem)
        }
        .onAppear {
            isPresented = true
        }
}

#Preview("With Data") {
    @Previewable @State var items = Item.sampleData
    
    ItemListView(items: $items)
}
```

### Error Handling in Views

**✅ DO: Handle async errors properly**
```swift
enum LoadState<T> {
    case loading
    case loaded(T)
    case failed(Error)
}

struct AsyncContentView: View {
    @State private var loadState: LoadState<[Item]> = .loading
    
    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView("Loading items...")
            case .loaded(let items):
                ItemListView(items: items)
            case .failed(let error):
                ErrorView(error: error) {
                    await loadData()
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        loadState = .loading
        do {
            let items = try await ItemService.fetchItems()
            loadState = .loaded(items)
        } catch {
            loadState = .failed(error)
        }
    }
}
```

### Modern Animation Patterns

**✅ DO: Use modern animation APIs**
```swift
struct AnimatedButton: View {
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button("Tap me") {
            // action
        }
        .scaleEffect(scale)
        .animation(.bouncy(duration: 0.6), value: scale)
        .onTapGesture {
            scale = 0.95
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scale = 1.0
            }
        }
    }
}

struct SmoothTransition: View {
    @State private var showDetails = false
    
    var body: some View {
        VStack {
            if showDetails {
                DetailView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Button("Toggle Details") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDetails.toggle()
                }
            }
        }
    }
}
```

### Custom Environment Values

**✅ DO: Create custom environment values**
```swift
// Define the key and default value
private struct UserPreferencesKey: EnvironmentKey {
    static let defaultValue = UserPreferences()
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.system
}

// Extend EnvironmentValues
extension EnvironmentValues {
    var userPreferences: UserPreferences {
        get { self[UserPreferencesKey.self] }
        set { self[UserPreferencesKey.self] = newValue }
    }
    
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// Usage in views
struct ContentView: View {
    @Environment(\.userPreferences) private var preferences
    @Environment(\.theme) private var theme
    
    var body: some View {
        Text("Hello")
            .foregroundColor(theme.primaryColor)
            .font(preferences.preferredFont)
    }
}

// Setting environment values
struct ParentView: View {
    @State private var preferences = UserPreferences()
    @State private var theme = Theme.dark
    
    var body: some View {
        ContentView()
            .environment(\.userPreferences, preferences)
            .environment(\.theme, theme)
    }
}
```

### SwiftUI Testing Best Practices

**✅ DO: Test view logic, not SwiftUI internals**
```swift
// Test the ViewModel/Model logic
@Test func testViewModelLogic() {
    let viewModel = ContentViewModel()
    
    // Test business logic
    viewModel.performAction()
    #expect(viewModel.isLoading == true)
    
    // Test state changes
    viewModel.updateData(newData)
    #expect(viewModel.items.count == 5)
}

// Test computed properties
@Test func testComputedProperties() {
    let viewModel = ContentViewModel()
    viewModel.items = [Item.sample1, Item.sample2]
    
    #expect(viewModel.hasItems == true)
    #expect(viewModel.displayTitle == "2 Items")
}
```

**❌ DON'T: Test SwiftUI view hierarchy**
```swift
// Bad: Testing internal SwiftUI structure
@Test func testViewHierarchy() {
    // This is brittle and depends on SwiftUI internals
    let view = ContentView()
    // Don't test view structure directly
}
```

**✅ DO: Test with ViewInspector for UI logic**
```swift
// When you need to test UI behavior
@Test func testButtonAction() throws {
    let viewModel = ContentViewModel()
    let view = ContentView(viewModel: viewModel)
    
    // Test that button triggers expected action
    try view.inspect().find(button: "Submit").tap()
    #expect(viewModel.isSubmitting == true)
}
```

---

## Critical Rules Summary

1. **Always use @Observable for ViewModels** (iOS 17+)
2. **Keep view bodies under 20 lines** - extract to computed properties
3. **Maximum 10 views per ViewBuilder**
4. **Use NavigationStack with type-safe routing**
5. **Prefer native components** (Form, List, Menu, etc.)
6. **Replace GeometryReader with modern APIs**
7. **Use semantic colors and system fonts**
8. **Design for all platforms from the start**
9. **Use task(id:) for reactive data loading**
10. **Test with _printChanges() for performance**
11. **Use @MainActor for all UI-related classes**
12. **Prefer computed properties over functions for view generation**
13. **Use .symbolVariant() for SF Symbol modifications**
14. **Implement proper .accessibilityIdentifier() for UI testing**
15. **Use .allowsHitTesting(false) instead of .disabled(true) for non-interactive overlays**
16. **Prefer .safeAreaInset() over manual padding calculations**
17. **Use .sensoryFeedback() for haptic feedback (iOS 17+)**
18. **Implement proper .searchable() scopes and tokens**
19. **Use .contentTransition() for smooth content changes**
20. **Apply .privacySensitive() for sensitive content**
21. **Use single multiplatform target** with platform conditionals
22. **Share 90%+ of code** between iOS and macOS
23. **Implement platform-specific features** using #if os() checks
24. **Test on all target platforms** regularly

## Architecture Guidelines

| Complexity | Pattern | When to Use |
|------------|---------|-------------|
| Simple | MV | Direct API calls, minimal logic |
| Medium | MVVM | Shared logic, testing needed |
| Complex | TCA/Clean | Large teams, complex state |

## Migration Checklist

- [ ] Replace ObservableObject → @Observable
- [ ] Update @StateObject → @State
- [ ] NavigationView → NavigationStack
- [ ] Use modern sheet APIs
- [ ] Implement containerRelativeFrame
- [ ] Add platform conditionals
- [ ] Update to iOS 18 & macOS 15 minimum
- [ ] Use Swift Testing framework
- [ ] Implement explicit animations
- [ ] Add proper focus management
- [ ] Use semantic spacing (no hardcoded values)
- [ ] Create single multiplatform target
- [ ] Add macOS window management
- [ ] Implement keyboard shortcuts
- [ ] Test with keyboard navigation
