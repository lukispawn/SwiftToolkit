# SwiftUI UI Patterns Rules

## View Composition

### DO: View Size Limits
✅ **ALWAYS keep view bodies under 20 lines**
- Extract complex UI to computed properties
- Use @ViewBuilder for complex layouts
- Break into smaller, focused views

```swift
// Good: Concise view body
struct UserProfileView: View {
    @State private var viewModel = UserProfileViewModel()
    
    var body: some View {
        VStack {
            headerSection
            profileContent
            actionButtons
        }
    }
}

// Extract to computed properties
private extension UserProfileView {
    var headerSection: some View {
        VStack {
            AsyncImage(url: viewModel.user.avatarURL)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            
            Text(viewModel.user.name)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}
```

❌ **NEVER have view bodies longer than 20 lines**

### DO: ViewBuilder Limits
✅ **ALWAYS limit ViewBuilder to maximum 10 views**
- Extract groups of views to separate computed properties
- Use helper views for complex layouts
- Break down large ViewBuilder blocks

```swift
// Good: Under 10 views
var body: some View {
    VStack {
        headerView
        contentView
        footerView
    }
}

// Bad: Too many views in one builder
var body: some View {
    VStack {
        Text("Title")
        Text("Subtitle")
        Image("icon")
        Button("Action 1") { }
        Button("Action 2") { }
        Button("Action 3") { }
        TextField("Input", text: $text)
        Toggle("Setting", isOn: $toggle)
        Slider(value: $value)
        Stepper("Count", value: $count)
        DatePicker("Date", selection: $date)
        // Too many views - extract to computed properties
    }
}
```

### DO: Computed Properties for View Generation
✅ **ALWAYS prefer computed properties over functions for view generation**

```swift
// Good: Computed property
var profileImage: some View {
    AsyncImage(url: user.avatarURL) { image in
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    } placeholder: {
        ProgressView()
    }
    .frame(width: 80, height: 80)
    .clipShape(Circle())
}

// Avoid: Function for view generation
func makeProfileImage() -> some View {
    // Less preferred approach
}
```

## Navigation Patterns

### DO: Modern Navigation
✅ **ALWAYS use NavigationStack for new projects**
- Supports programmatic navigation
- Type-safe routing
- Better performance than NavigationView

```swift
// Correct: NavigationStack
NavigationStack(path: $navigationPath) {
    HomeView()
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .detail(let item):
                DetailView(item: item)
            case .settings:
                SettingsView()
            }
        }
}
```

❌ **NEVER use NavigationView for new projects**

### DO: Type-Safe Routing
✅ **ALWAYS implement type-safe routing with enums**

```swift
enum Route: Hashable {
    case detail(Item)
    case settings
    case profile(User)
}

struct ContentView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(items) { item in
                NavigationLink(value: Route.detail(item)) {
                    ItemRow(item: item)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detail(let item):
                    DetailView(item: item)
                case .settings:
                    SettingsView()
                case .profile(let user):
                    ProfileView(user: user)
                }
            }
        }
    }
}
```

### DO: Navigation State Management
✅ **ALWAYS use @State for navigation paths**

```swift
struct MainView: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)
        }
    }
}
```

## Native Components

### DO: Form Usage
✅ **ALWAYS prefer Form over VStack for data entry**

```swift
// Correct: Form for data entry
Form {
    Section("Personal Information") {
        TextField("First Name", text: $firstName)
        TextField("Last Name", text: $lastName)
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
    }
    
    Section("Preferences") {
        Toggle("Notifications", isOn: $notificationsEnabled)
        Picker("Theme", selection: $selectedTheme) {
            ForEach(Theme.allCases) { theme in
                Text(theme.rawValue).tag(theme)
            }
        }
    }
}
```

### DO: List vs Form Guidelines
✅ **ALWAYS choose the right container**

**Use Form for:**
- Data entry and editing
- Settings screens
- Multi-section input forms
- Mixed control types

**Use List for:**
- Displaying collections
- Navigation menus
- Read-only content
- Simple item lists

```swift
// Form: Data entry
Form {
    Section("Account") {
        TextField("Username", text: $username)
        SecureField("Password", text: $password)
    }
}

// List: Display collection
List(users) { user in
    NavigationLink(value: user) {
        UserRow(user: user)
    }
}
```

### DO: Menu Usage
✅ **ALWAYS use Menu for contextual actions**

```swift
Menu {
    Button("Edit", systemImage: "pencil") {
        // Edit action
    }
    
    Button("Share", systemImage: "square.and.arrow.up") {
        // Share action
    }
    
    Divider()
    
    Button("Delete", systemImage: "trash", role: .destructive) {
        // Delete action
    }
} label: {
    Label("Actions", systemImage: "ellipsis.circle")
}
```

### DO: ConfirmationDialog
✅ **ALWAYS use ConfirmationDialog for destructive actions**

```swift
.confirmationDialog(
    "Delete Item",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        deleteItem()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This action cannot be undone.")
}
```

## Sheet and Modal Presentations

### DO: Modern Sheet APIs
✅ **ALWAYS use modern sheet presentation APIs**

```swift
// Modern sheet with detents (iOS 16+)
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
}

// Full screen cover when needed
.fullScreenCover(isPresented: $showFullScreen) {
    FullScreenContent()
}
```

### DO: Presentation Sizing
✅ **ALWAYS specify appropriate presentation sizing**

```swift
// For forms and detailed content
.sheet(isPresented: $showSheet) {
    DetailForm()
        .presentationSizing(.form)
}

// For content that needs specific size
.sheet(isPresented: $showSheet) {
    ContentView()
        .presentationSizing(.fitted)
}
```

## Toolbar Management

### DO: Semantic Toolbar Placement
✅ **ALWAYS use semantic toolbar placement**

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
            dismiss()
        }
    }
    
    ToolbarItem(placement: .topBarTrailing) {
        Button("Save") {
            save()
        }
        .disabled(!isFormValid)
    }
    
    ToolbarItem(placement: .principal) {
        Text("Edit Profile")
            .font(.headline)
    }
}
```

### DO: Platform-Specific Toolbar
✅ **ALWAYS adapt toolbar for platform**

```swift
.toolbar {
    #if os(iOS)
    ToolbarItem(placement: .topBarTrailing) {
        EditButton()
    }
    #elseif os(macOS)
    ToolbarItem(placement: .primaryAction) {
        Button("Edit") {
            // Edit action
        }
    }
    #endif
}
```

## Empty States

### DO: ContentUnavailableView
✅ **ALWAYS use ContentUnavailableView for empty states**

```swift
// Empty search results
if searchResults.isEmpty {
    ContentUnavailableView.search(text: searchText)
} else {
    List(searchResults) { result in
        ResultRow(result: result)
    }
}

// Custom empty state
if items.isEmpty {
    ContentUnavailableView(
        "No Items",
        systemImage: "tray",
        description: Text("Add your first item to get started")
    )
}
```

## Accessibility

### DO: VoiceOver Support
✅ **ALWAYS provide accessibility support**

```swift
// Proper accessibility labels
Button(action: toggleFavorite) {
    Image(systemName: isFavorite ? "heart.fill" : "heart")
}
.accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

// Accessibility hints
TextField("Search", text: $searchText)
    .accessibilityHint("Enter text to search items")

// Grouped accessibility
HStack {
    Image(systemName: "star.fill")
    Text("4.5 stars")
}
.accessibilityElement(children: .combine)
```

### DO: Dynamic Type Support
✅ **ALWAYS support Dynamic Type**

```swift
// Scalable text
Text("Important Information")
    .font(.headline)
    .dynamicTypeSize(.large...(.accessibility3))

// Scalable layouts
VStack(spacing: 8) {
    Text("Title")
        .font(.title2)
    Text("Description")
        .font(.body)
}
.dynamicTypeSize(.large...(.accessibility5))
```

## Design System

### DO: System Colors
✅ **ALWAYS use semantic colors**

```swift
// Good: Semantic colors
Text("Primary Text")
    .foregroundColor(.primary)

Text("Secondary Text")
    .foregroundColor(.secondary)

Rectangle()
    .fill(.accent)

// For custom colors, use system materials
.background(.regularMaterial)
```

❌ **NEVER use hardcoded colors**

### DO: System Fonts
✅ **ALWAYS use system fonts and text styles**

```swift
// Good: System text styles
Text("Title")
    .font(.largeTitle)

Text("Body")
    .font(.body)

Text("Caption")
    .font(.caption)

// Custom weight with system font
Text("Headline")
    .font(.system(.title2, weight: .semibold))
```

### DO: Spacing Guidelines
✅ **ALWAYS use semantic spacing**

```swift
// Good: Semantic spacing
VStack(spacing: 16) {
    // Content
}
.padding()

// Platform-specific spacing
VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16) {
    // Content
}
```

❌ **NEVER use hardcoded spacing values**

## Button Styling

### DO: Button Styles
✅ **ALWAYS use appropriate button styles**

```swift
// Primary actions
Button("Continue") {
    // Action
}
.buttonStyle(.borderedProminent)

// Secondary actions
Button("Cancel") {
    // Action
}
.buttonStyle(.bordered)

// Subtle actions
Button("Learn More") {
    // Action
}
.buttonStyle(.plain)
```

### DO: SF Symbols
✅ **ALWAYS use SF Symbols for icons**

```swift
// Good: SF Symbols
Image(systemName: "heart.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundColor(.red)

Button(action: share) {
    Label("Share", systemImage: "square.and.arrow.up")
}

// Symbol variants
Image(systemName: "wifi")
    .symbolVariant(.slash)
```

## Search and Filtering

### DO: Searchable Implementation
✅ **ALWAYS implement searchable with proper scopes**

```swift
NavigationStack {
    List(filteredItems) { item in
        ItemRow(item: item)
    }
    .searchable(text: $searchText, prompt: "Search items")
    .searchScopes($searchScope) {
        ForEach(SearchScope.allCases) { scope in
            Text(scope.title)
        }
    }
}
```

## Anti-Patterns to Avoid

### DON'T: Common UI Mistakes
❌ **NEVER use GeometryReader when alternatives exist**
❌ **NEVER hardcode dimensions**
❌ **NEVER ignore accessibility**
❌ **NEVER use deprecated navigation APIs**
❌ **NEVER create overly complex view hierarchies**
❌ **NEVER ignore platform differences**

### DON'T: Layout Mistakes
❌ **NEVER use manual frame calculations**
❌ **NEVER ignore safe areas**
❌ **NEVER use fixed sizes for text**
❌ **NEVER skip empty state handling**
❌ **NEVER use non-semantic colors**