# MVVM Architecture in SwiftUI

## Table of Contents

1. [Overview](#overview)
2. [Modern @Observable Pattern](#modern-observable-pattern)
3. [MainActor Usage](#mainactor-usage)
4. [Service Protocol Foundation](#service-protocol-foundation)
5. [ViewModel Best Practices](#viewmodel-best-practices)
6. [Dependency Injection Patterns](#dependency-injection-patterns)
7. [State Management with ContentUnavailableView](#state-management-with-contentunavailableview)
8. [Extension-Based File Organization](#extension-based-file-organization)
9. [Preview Strategies](#preview-strategies)
10. [Testing ViewModels](#testing-viewmodels)
11. [MVVM + Service Pattern Best Practices](#mvvm--service-pattern-best-practices)

---

## Overview

MVVM (Model-View-ViewModel) is a design pattern that separates business logic from UI code in SwiftUI applications. This pattern, combined with modern SwiftUI features like `@Observable` and service protocols, creates maintainable, testable, and scalable applications.

**Key Benefits:**
- **Separation of Concerns**: UI logic stays in views, business logic in ViewModels
- **Testability**: ViewModels can be easily unit tested
- **Reusability**: Business logic can be shared across different views
- **Maintainability**: Clear structure makes code easier to understand and modify

---

## Modern @Observable Pattern

### iOS 17+ Approach

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

## MainActor Usage

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

---

## Service Protocol Foundation

**✅ DO: Define service protocols for abstraction**
```swift
// Good: Clear protocol definition
protocol ProductDataService {
    func loadProducts() async throws -> [Product]
}

// Good: Production implementation
final class ProductionProductService: ProductDataService {
    func loadProducts() async throws -> [Product] {
        // Real API/Database implementation
        let response = try await URLSession.shared.data(from: apiURL)
        return try JSONDecoder().decode([Product].self, from: response.0)
    }
}

// Good: Configurable mock for testing
final class MockProductService: ProductDataService {
    var productsToReturn: [Product]
    var shouldThrowError: Bool
    var delay: TimeInterval
    
    init(
        products: [Product] = Product.mockData,
        shouldThrowError: Bool = false,
        delay: TimeInterval = 0
    ) {
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

---

## ViewModel Best Practices

**✅ DO: Use @Observable with @MainActor and proper structure**
```swift
struct ProductListView: View {
    @State private var viewModel: ViewModel
    
    // Good: Dependency injection through init
    init(productService: ProductDataService = ProductionProductService()) {
        self._viewModel = State(wrappedValue: ViewModel(productService: productService))
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Products")
                .task {
                    await viewModel.loadProducts()
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading products...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else if viewModel.products.isEmpty {
            emptyStateView
        } else {
            productList
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Products",
            systemImage: "cart",
            description: Text("No products available at the moment.")
        )
    }
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

extension ProductListView {
    @MainActor
    @Observable
    final class ViewModel {
        // Good: Private service dependency
        private let productService: ProductDataService
        
        // Good: private(set) for state properties
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
        
        func retry() async {
            await loadProducts()
        }
    }
}
```

**❌ DON'T: Use outdated patterns or poor structure**
```swift
// Bad: Using @StateObject with ObservableObject
struct OldProductListView: View {
    @StateObject private var viewModel = OldViewModel()
    
    var body: some View {
        // Implementation
    }
}

class OldViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    // Missing @MainActor, using old patterns
}

// Bad: Direct API calls in ViewModel
extension ProductListView {
    @Observable
    class BadViewModel {
        var products: [Product] = []
        
        func loadProducts() async {
            // Bad: Direct URL dependencies, no abstraction
            let url = URL(string: "https://api.example.com/products")!
            let data = try! await URLSession.shared.data(from: url).0
            products = try! JSONDecoder().decode([Product].self, from: data)
        }
    }
}
```

---

## Dependency Injection Patterns

**✅ DO: Use service container for complex apps**
```swift
@MainActor
final class ServiceContainer: ObservableObject {
    lazy var productService: ProductDataService = {
        #if DEBUG
        return MockProductService()
        #else
        return ProductionProductService()
        #endif
    }()
    
    lazy var userService: UserService = {
        #if DEBUG
        return MockUserService()
        #else
        return ProductionUserService()
        #endif
    }()
}

// Usage in app root
struct ContentView: View {
    @StateObject private var serviceContainer = ServiceContainer()
    
    var body: some View {
        TabView {
            ProductListView(productService: serviceContainer.productService)
                .tabItem { Label("Products", systemImage: "cart") }
            
            UserProfileView(userService: serviceContainer.userService)
                .tabItem { Label("Profile", systemImage: "person") }
        }
    }
}
```

---

## State Management with ContentUnavailableView

**✅ DO: Handle all states comprehensively**
```swift
extension ProductListView {
    @ViewBuilder
    private var content: some View {
        switch (viewModel.isLoading, viewModel.products.isEmpty, viewModel.errorMessage) {
        case (true, _, _):
            ProgressView("Loading products...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case (false, _, let error?) :
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
                .buttonStyle(.borderedProminent)
            }
            
        case (false, true, nil):
            ContentUnavailableView(
                "No Products",
                systemImage: "cart",
                description: Text("No products available at the moment.")
            )
            
        case (false, false, nil):
            List(viewModel.products) { product in
                ProductRowView(product: product)
            }
        }
    }
}
```

---

## Extension-Based File Organization

### Small Features (<150 lines)
```swift
// File: Features/Settings/SettingsView.swift
struct SettingsView: View {
    @State private var viewModel = ViewModel()
    
    var body: some View {
        // Implementation
    }
}

extension SettingsView {
    @MainActor
    @Observable
    final class ViewModel {
        private(set) var settings: Settings = .default
        
        func updateSetting(_ setting: Setting, value: Bool) {
            // Implementation
        }
    }
    
    struct Settings {
        var notificationsEnabled: Bool
        var darkModeEnabled: Bool
        
        static let `default` = Settings(
            notificationsEnabled: true,
            darkModeEnabled: false
        )
    }
    
    enum Setting {
        case notifications, darkMode
    }
}
```

### Medium Features (150-400 lines)
```
Features/
└── UserProfile/
    ├── UserProfileView.swift           // Main view
    ├── UserProfileView+ViewModel.swift // ViewModel extension  
    └── UserProfileService.swift        // Service (if feature-specific)
```

### Large Features (400+ lines)
```
Features/
└── ProductList/
    ├── ProductListView.swift           // Main view structure only
    ├── ProductListView+ViewModel.swift // ViewModel extension
    ├── Views/
    │   ├── ProductListView+RowView.swift    // Row component
    │   ├── ProductListView+HeaderView.swift  // Header component
    │   └── ProductListView+FilterBar.swift  // Filter component
    ├── Models/
    │   └── Product.swift                     // Data models
    └── Services/
        ├── ProductDataService.swift          // Service protocol
        ├── ProductionProductService.swift    // Production implementation
        └── MockProductService.swift          // Mock for testing
```

---

## Preview Strategies

**✅ DO: Create comprehensive preview states**
```swift
#Preview("Success State") {
    ProductListView(productService: MockProductService())
}

#Preview("Loading State") {
    ProductListView(productService: MockProductService(delay: 5))
}

#Preview("Error State") {
    ProductListView(productService: MockProductService(shouldThrowError: true))
}

#Preview("Empty State") {
    ProductListView(productService: MockProductService(products: []))
}

#Preview("Large Dataset") {
    ProductListView(productService: MockProductService(products: Product.largeDataset))
}
```

---

## Testing ViewModels

### Basic ViewModel Testing
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

### Testing State Transitions
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

---

## MVVM + Service Pattern Best Practices

### 1. ViewModel Guidelines
- Always use `@MainActor` for UI thread safety
- Mark as `final` to prevent inheritance
- Use `private(set)` for state properties
- Provide clear async methods for actions
- Handle loading, error, and success states

### 2. Service Pattern
- Use protocols for abstraction and testing
- Implement `async/throws` for all service methods
- Create comprehensive mocks with configurable behavior
- Use `final class` for service implementations

### 3. Dependency Injection
- Inject services through View init with defaults
- Use ServiceContainer for complex dependency graphs
- Prefer protocol types over concrete implementations
- Enable easy mocking for testing and previews

### 4. File Organization
- Use `+` in filenames to show relationships
- Keep main view file focused on layout and structure
- Share common services across features when appropriate
- Start simple and refactor to larger structure as feature grows

### 5. State Management
- Separate loading, error, and data states clearly
- Use `ContentUnavailableView` for empty/error states
- Provide retry functionality for errors
- Handle all possible state combinations

### 6. Testing & Previews
- Create mocks that can simulate all scenarios
- Use `#Preview` for different states
- Test edge cases (empty, error, loading)
- Verify proper state transitions

---

## Summary

The MVVM pattern in SwiftUI, when combined with modern features like `@Observable`, `@MainActor`, and service protocols, provides a robust foundation for building maintainable applications. Key takeaways:

1. **Use `@Observable`** instead of `ObservableObject` for new code
2. **Always apply `@MainActor`** to ViewModels for thread safety
3. **Abstract dependencies** through service protocols
4. **Test thoroughly** with comprehensive mock implementations
5. **Organize files consistently** using extension-based patterns
6. **Handle all states** including loading, error, and empty states

This pattern scales well from small features to complex applications while maintaining testability and code clarity.