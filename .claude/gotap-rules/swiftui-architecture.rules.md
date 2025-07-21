# SwiftUI Architecture Rules

## Project Setup

### DO: Minimum Deployment Target
✅ **ALWAYS set minimum deployment target to iOS 18.0, macOS 15.0**
- Enables access to latest SwiftUI features
- Ensures consistent behavior across platforms
- Allows use of modern APIs like @Entry, enhanced ScrollView

```swift
// In target settings
iOS Deployment Target: 18.0
macOS Deployment Target: 15.0
```

### DO: Single Target Architecture
✅ **ALWAYS use single multiplatform target**
- Reduces complexity and maintenance overhead
- Enables maximum code sharing (90%+)
- Simplifies build configuration

```swift
// Correct: Single target with platform conditionals
#if os(iOS)
    .navigationBarTitleDisplayMode(.large)
#elseif os(macOS)
    .navigationSubtitle("macOS Version")
#endif
```

❌ **NEVER create separate targets for iOS/macOS unless absolutely necessary**

### DO: App Entry Point
✅ **ALWAYS use @main with proper scene configuration**

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
```

## State Management

### DO: Modern @Observable Pattern
✅ **ALWAYS use @Observable for ViewModels (iOS 17+)**
- Eliminates need for @Published and @StateObject
- Automatic observation of all properties
- Better performance and cleaner code

```swift
// Correct: Modern @Observable
@Observable
class UserViewModel {
    var users: [User] = []
    var isLoading = false
    var errorMessage: String?
}

// Usage in View
struct UserView: View {
    @State private var viewModel = UserViewModel()
    
    var body: some View {
        // Automatically observes all properties
        List(viewModel.users) { user in
            Text(user.name)
        }
    }
}
```

❌ **NEVER use ObservableObject for new code**

```swift
// Incorrect: Legacy pattern
class UserViewModel: ObservableObject {
    @Published var users: [User] = []
}
```

### DO: Property Wrapper Rules
✅ **ALWAYS follow property wrapper hierarchy**
- Use @State for local view state
- Use @Binding for parent-child communication
- Use @Environment for app-wide state

```swift
struct ParentView: View {
    @State private var isPresented = false
    
    var body: some View {
        ChildView(isPresented: $isPresented)
    }
}

struct ChildView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        Button("Toggle") {
            isPresented.toggle()
        }
    }
}
```

❌ **NEVER use @StateObject with @Observable classes**

## MVVM Architecture

### DO: ViewModels with @MainActor
✅ **ALWAYS mark ViewModels with @MainActor**
- Ensures UI updates happen on main thread
- Prevents threading issues
- Required for @Observable pattern

```swift
@MainActor
@Observable
class ProductViewModel {
    var products: [Product] = []
    var isLoading = false
    
    func loadProducts() {
        isLoading = true
        Task {
            // Async work
            products = await productService.fetchProducts()
            isLoading = false
        }
    }
}
```

### DO: Service Layer Pattern
✅ **ALWAYS implement service protocols for data access**
- Enables testing with mock implementations
- Separates concerns properly
- Supports dependency injection

```swift
protocol UserServiceProtocol {
    func fetchUsers() async throws -> [User]
    func createUser(_ user: User) async throws
}

class UserService: UserServiceProtocol {
    func fetchUsers() async throws -> [User] {
        // Implementation
    }
    
    func createUser(_ user: User) async throws {
        // Implementation
    }
}

// In ViewModel
@MainActor
@Observable
class UserViewModel {
    private let userService: UserServiceProtocol
    var users: [User] = []
    
    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }
    
    func loadUsers() async {
        do {
            users = try await userService.fetchUsers()
        } catch {
            // Handle error
        }
    }
}
```

### DO: ViewModel Size Limits
✅ **ALWAYS keep ViewModels under 200 lines**
- Break large ViewModels into smaller, focused ones
- Use composition over inheritance
- Extract business logic into services

```swift
// Good: Focused ViewModel
@MainActor
@Observable
class UserListViewModel {
    private let userService: UserServiceProtocol
    var users: [User] = []
    var isLoading = false
    
    // Max ~50 lines of logic
}

// Extract to separate ViewModels
@MainActor
@Observable
class UserDetailViewModel {
    private let userService: UserServiceProtocol
    var user: User?
    
    // Another focused ViewModel
}
```

## File Organization

### DO: Extension-Based Organization
✅ **ALWAYS organize code using extensions**

```swift
// MyView.swift
struct MyView: View {
    var body: some View {
        // View implementation
    }
}

// MARK: - Private Views
private extension MyView {
    var headerView: some View {
        // Header implementation
    }
    
    var footerView: some View {
        // Footer implementation
    }
}

// MARK: - Actions
private extension MyView {
    func handleButtonTap() {
        // Action implementation
    }
}
```

### DO: File Structure Pattern
✅ **ALWAYS follow consistent file structure**

```
MyFeature/
├── Views/
│   ├── MyFeatureView.swift
│   └── MyFeatureDetailView.swift
├── ViewModels/
│   ├── MyFeatureViewModel.swift
│   └── MyFeatureDetailViewModel.swift
├── Services/
│   ├── MyFeatureService.swift
│   └── MyFeatureServiceProtocol.swift
└── Models/
    └── MyFeatureModel.swift
```

### DO: Small Features Organization
✅ **For features under 150 lines, use single file with extensions**

```swift
// SimpleFeature.swift
struct SimpleFeatureView: View {
    // View implementation
}

// MARK: - ViewModel
@MainActor
@Observable
class SimpleFeatureViewModel {
    // ViewModel implementation
}

// MARK: - Service
protocol SimpleFeatureServiceProtocol {
    // Service protocol
}

class SimpleFeatureService: SimpleFeatureServiceProtocol {
    // Service implementation
}
```

## Dependency Injection

### DO: Protocol-Based Dependency Injection
✅ **ALWAYS use protocol-based dependency injection**

```swift
// Define protocol
protocol DataServiceProtocol {
    func fetchData() async throws -> [DataItem]
}

// Implementation
class DataService: DataServiceProtocol {
    func fetchData() async throws -> [DataItem] {
        // Implementation
    }
}

// Mock for testing
class MockDataService: DataServiceProtocol {
    func fetchData() async throws -> [DataItem] {
        // Mock implementation
    }
}

// ViewModel with dependency injection
@MainActor
@Observable
class DataViewModel {
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol = DataService()) {
        self.dataService = dataService
    }
}
```

### DO: Environment-Based Injection
✅ **ALWAYS use environment for app-wide dependencies**

```swift
// Define environment key
private struct DataServiceKey: EnvironmentKey {
    static let defaultValue: DataServiceProtocol = DataService()
}

extension EnvironmentValues {
    var dataService: DataServiceProtocol {
        get { self[DataServiceKey.self] }
        set { self[DataServiceKey.self] = newValue }
    }
}

// Usage in View
struct DataView: View {
    @Environment(\.dataService) private var dataService
    @State private var viewModel: DataViewModel
    
    init() {
        // Initialize with environment dependency
        self._viewModel = State(initialValue: DataViewModel())
    }
    
    var body: some View {
        // View implementation
    }
    .onAppear {
        viewModel.setDataService(dataService)
    }
}
```

## Code Quality Rules

### DO: View Size Limits
✅ **ALWAYS keep view bodies under 20 lines**
- Extract complex UI to computed properties
- Use @ViewBuilder for complex layouts
- Break into smaller, focused views

```swift
// Good: Concise view body
struct UserView: View {
    @State private var viewModel = UserViewModel()
    
    var body: some View {
        VStack {
            headerView
            contentView
            footerView
        }
    }
}

// Extract to computed properties
private extension UserView {
    var headerView: some View {
        // Header implementation
    }
    
    var contentView: some View {
        // Content implementation
    }
    
    var footerView: some View {
        // Footer implementation
    }
}
```

❌ **NEVER have view bodies longer than 20 lines**

### DO: Function Length Guidelines
✅ **ALWAYS keep functions under 15 lines**
- Extract complex logic to separate functions
- Use early returns to reduce nesting
- Break down complex operations

```swift
// Good: Short, focused function
func validateUser(_ user: User) -> Bool {
    guard !user.email.isEmpty else { return false }
    guard user.email.contains("@") else { return false }
    guard user.age >= 18 else { return false }
    return true
}

// Extract complex logic
func processUserData(_ user: User) {
    validateUser(user)
    sanitizeUserData(user)
    saveUserData(user)
}
```

## Architecture Guidelines

### DO: Complexity-Based Pattern Selection
✅ **ALWAYS choose architecture based on complexity**

| Complexity | Pattern | When to Use |
|------------|---------|-------------|
| Simple | MV | Direct API calls, minimal logic |
| Medium | MVVM | Shared logic, testing needed |
| Complex | TCA/Clean | Large teams, complex state |

### DO: Migration from Legacy Patterns
✅ **ALWAYS migrate legacy patterns systematically**

Migration checklist:
- [ ] Replace ObservableObject → @Observable
- [ ] Update @StateObject → @State
- [ ] Convert to @MainActor pattern
- [ ] Implement service protocols
- [ ] Extract business logic from Views
- [ ] Add proper error handling
- [ ] Implement dependency injection

## Anti-Patterns to Avoid

### DON'T: Common Architecture Mistakes
❌ **NEVER put business logic in Views**
❌ **NEVER use singletons for testable components**
❌ **NEVER ignore error handling**
❌ **NEVER skip dependency injection**
❌ **NEVER create god objects (classes > 200 lines)**
❌ **NEVER use force unwrapping in production code**

### DON'T: Legacy Patterns
❌ **NEVER use these deprecated patterns**
- ObservableObject (use @Observable)
- @StateObject (use @State)
- Manual @Published properties
- Nested ViewModels without proper separation
- Direct API calls from Views