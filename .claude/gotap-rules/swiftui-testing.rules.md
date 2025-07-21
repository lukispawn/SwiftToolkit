# SwiftUI Testing Rules

## Swift Testing Framework

### DO: Use Swift Testing for All New Tests
✅ **ALWAYS use Swift Testing framework (@Test) for new projects**
- Modern testing approach with better syntax
- Improved async testing support
- Better error reporting and debugging

```swift
import Testing
import SwiftUI

@Test("User view model loads users correctly")
func testUserViewModelLoading() async {
    let mockService = MockUserService()
    let viewModel = UserViewModel(userService: mockService)
    
    await viewModel.loadUsers()
    
    #expect(viewModel.users.count == 3)
    #expect(!viewModel.isLoading)
    #expect(viewModel.errorMessage == nil)
}
```

### DO: Implement Comprehensive Test Coverage
✅ **ALWAYS test ViewModels comprehensively**

```swift
@Test("User filtering works correctly")
func testUserFiltering() {
    let viewModel = UserViewModel()
    viewModel.users = [
        User(name: "John", isActive: true),
        User(name: "Jane", isActive: false),
        User(name: "Bob", isActive: true)
    ]
    
    viewModel.showActiveOnly = true
    
    #expect(viewModel.filteredUsers.count == 2)
    #expect(viewModel.filteredUsers.allSatisfy { $0.isActive })
}
```

### DO: Test State Transitions
✅ **ALWAYS test loading state transitions**

```swift
@Test("Loading state transitions correctly")
func testLoadingStateTransitions() async {
    let mockService = MockUserService()
    let viewModel = UserViewModel(userService: mockService)
    
    #expect(!viewModel.isLoading)
    
    let loadingTask = Task {
        await viewModel.loadUsers()
    }
    
    // Verify loading state
    #expect(viewModel.isLoading)
    
    await loadingTask.value
    #expect(!viewModel.isLoading)
    #expect(viewModel.users.count > 0)
}
```

## Parameterized Testing

### DO: Use Parameterized Tests
✅ **ALWAYS use parameterized tests for multiple scenarios**

```swift
@Test(
    "Email validation works correctly",
    arguments: [
        ("valid@example.com", true),
        ("invalid-email", false),
        ("", false),
        ("user@domain.co.uk", true)
    ]
)
func testEmailValidation(email: String, isValid: Bool) {
    #expect(EmailValidator.validate(email) == isValid)
}
```

### DO: Test Edge Cases
✅ **ALWAYS test edge cases and error conditions**

```swift
@Test("Network error handling")
func testNetworkErrorHandling() async {
    let mockService = MockUserService()
    mockService.shouldThrowError = true
    
    let viewModel = UserViewModel(userService: mockService)
    
    await viewModel.loadUsers()
    
    #expect(viewModel.users.isEmpty)
    #expect(viewModel.errorMessage != nil)
    #expect(!viewModel.isLoading)
}
```

## Async Testing

### DO: Test Async Operations
✅ **ALWAYS test async operations properly**

```swift
@Test
func testAsyncDataFetching() async {
    let service = DataService()
    
    do {
        let data = try await service.fetchData()
        #expect(data.count > 0)
    } catch {
        Issue.record("Data fetching failed: \(error)")
    }
}

@Test
func testAsyncErrorHandling() async {
    let service = DataService()
    
    await #expect(throws: NetworkError.self) {
        try await service.fetchDataWithError()
    }
}
```

## Testing ViewModels

### DO: Test ViewModel Logic
✅ **ALWAYS test ViewModel business logic**

```swift
@Test("Product view model calculates total correctly")
func testProductTotalCalculation() {
    let viewModel = ProductViewModel()
    viewModel.products = [
        Product(price: 10.0, quantity: 2),
        Product(price: 15.0, quantity: 1),
        Product(price: 5.0, quantity: 3)
    ]
    
    #expect(viewModel.totalPrice == 50.0)
    #expect(viewModel.totalItems == 6)
}
```

### DO: Test State Management
✅ **ALWAYS test @Observable state changes**

```swift
@Test
func testViewModelStateChanges() {
    let viewModel = TaskViewModel()
    
    #expect(viewModel.tasks.isEmpty)
    
    viewModel.addTask(title: "New Task")
    
    #expect(viewModel.tasks.count == 1)
    #expect(viewModel.tasks.first?.title == "New Task")
}
```

## Testing with Dependencies

### DO: Use Mock Services
✅ **ALWAYS use dependency injection for testability**

```swift
protocol UserServiceProtocol {
    func fetchUsers() async throws -> [User]
}

class MockUserService: UserServiceProtocol {
    var users: [User] = []
    var shouldThrowError = false
    
    func fetchUsers() async throws -> [User] {
        if shouldThrowError {
            throw NetworkError.connectionFailed
        }
        return users
    }
}

@Test
func testUserViewModelWithMockService() async {
    let mockService = MockUserService()
    mockService.users = [
        User(name: "Test User", email: "test@example.com")
    ]
    
    let viewModel = UserViewModel(userService: mockService)
    await viewModel.loadUsers()
    
    #expect(viewModel.users.count == 1)
    #expect(viewModel.users.first?.name == "Test User")
}
```

## UI Testing with Swift Testing

### DO: Test UI Components
✅ **ALWAYS test UI behavior**

```swift
@Test
func testButtonAction() async {
    let viewModel = CounterViewModel()
    
    // Simulate button tap
    viewModel.increment()
    
    #expect(viewModel.count == 1)
}

@Test("Navigation presents correct view")
func testNavigationPresentation() {
    let coordinator = NavigationCoordinator()
    
    coordinator.presentDetail(for: Item(id: 1))
    
    #expect(coordinator.currentRoute == .detail(Item(id: 1)))
}
```

### DO: Test View State
✅ **ALWAYS test view state changes**

```swift
@Test
func testViewStateUpdates() {
    let viewModel = ToggleViewModel()
    
    #expect(!viewModel.isToggled)
    
    viewModel.toggle()
    
    #expect(viewModel.isToggled)
}
```

## Test Organization

### DO: Organize Tests by Feature
✅ **ALWAYS organize tests by feature/component**

```swift
@Suite("User Management Tests")
struct UserManagementTests {
    @Test("User creation")
    func testUserCreation() {
        // Test implementation
    }
    
    @Test("User validation")
    func testUserValidation() {
        // Test implementation
    }
}

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Login success")
    func testLoginSuccess() async {
        // Test implementation
    }
    
    @Test("Login failure")
    func testLoginFailure() async {
        // Test implementation
    }
}
```

### DO: Use Test Tags
✅ **ALWAYS use appropriate test tags**

```swift
@Test(.tags(.critical, .authentication))
func testCriticalAuthFlow() async {
    // Critical authentication test
}

@Test(.disabled("Waiting for API implementation"))
func testPendingFeature() {
    // Temporarily disabled test
}

@Test(.timeLimit(.minutes(1)))
func testPerformanceCriticalOperation() {
    // Performance-sensitive test
}
```

## Test Configuration

### DO: Setup and Teardown
✅ **ALWAYS implement proper test setup and teardown**

```swift
@Suite("Database Tests")
struct DatabaseTests {
    var database: TestDatabase!
    
    init() {
        database = TestDatabase()
        database.setup()
    }
    
    deinit {
        database.teardown()
    }
    
    @Test
    func testDatabaseOperation() {
        // Test using database
    }
}
```

### DO: Test Isolation
✅ **ALWAYS ensure test isolation**

```swift
@Test
func testIsolatedUserCreation() {
    let service = UserService()
    let initialCount = service.userCount
    
    service.createUser(name: "Test User")
    
    #expect(service.userCount == initialCount + 1)
    
    // Cleanup
    service.deleteUser(name: "Test User")
}
```

## Performance Testing

### DO: Test Performance
✅ **ALWAYS test performance-critical operations**

```swift
@Test(.timeLimit(.seconds(2)))
func testDataProcessingPerformance() {
    let processor = DataProcessor()
    let largeDataset = Array(1...10000)
    
    let result = processor.processData(largeDataset)
    
    #expect(result.count == largeDataset.count)
}
```

### DO: Memory Testing
✅ **ALWAYS test for memory leaks**

```swift
@Test
func testViewModelMemoryManagement() {
    weak var weakViewModel: UserViewModel?
    
    autoreleasepool {
        let viewModel = UserViewModel()
        weakViewModel = viewModel
        
        // Use viewModel
        viewModel.loadUsers()
    }
    
    #expect(weakViewModel == nil, "ViewModel should be deallocated")
}
```

## Error Testing

### DO: Test Error Conditions
✅ **ALWAYS test error handling**

```swift
@Test("Network timeout handling")
func testNetworkTimeout() async {
    let service = NetworkService()
    
    await #expect(throws: NetworkError.timeout) {
        try await service.fetchWithTimeout(seconds: 0.1)
    }
}

@Test("Invalid input handling")
func testInvalidInputHandling() {
    let validator = InputValidator()
    
    #expect(throws: ValidationError.invalidEmail) {
        try validator.validateEmail("")
    }
}
```

## Test Data Management

### DO: Use Test Fixtures
✅ **ALWAYS use consistent test data**

```swift
enum TestData {
    static let sampleUsers = [
        User(name: "John Doe", email: "john@example.com"),
        User(name: "Jane Smith", email: "jane@example.com")
    ]
    
    static let sampleProducts = [
        Product(name: "iPhone", price: 999.0),
        Product(name: "iPad", price: 799.0)
    ]
}

@Test
func testWithSampleData() {
    let viewModel = UserViewModel()
    viewModel.users = TestData.sampleUsers
    
    #expect(viewModel.users.count == 2)
}
```

### DO: Test Data Consistency
✅ **ALWAYS ensure test data consistency**

```swift
@Test
func testDataConsistency() {
    let user = User(name: "Test User", email: "test@example.com")
    let serialized = user.toJSON()
    let deserialized = User.fromJSON(serialized)
    
    #expect(deserialized.name == user.name)
    #expect(deserialized.email == user.email)
}
```

## Integration Testing

### DO: Test Service Integration
✅ **ALWAYS test service integration**

```swift
@Test
func testServiceIntegration() async {
    let userService = UserService()
    let viewModel = UserViewModel(userService: userService)
    
    await viewModel.loadUsers()
    
    #expect(viewModel.users.count > 0)
    #expect(viewModel.errorMessage == nil)
}
```

### DO: Test Navigation Flow
✅ **ALWAYS test navigation flows**

```swift
@Test
func testNavigationFlow() {
    let coordinator = AppCoordinator()
    
    coordinator.showLogin()
    #expect(coordinator.currentScreen == .login)
    
    coordinator.loginSuccessful()
    #expect(coordinator.currentScreen == .main)
}
```

## Testing Best Practices

### DO: Follow Testing Principles
✅ **ALWAYS follow these testing principles**

1. **Test behavior, not implementation**
2. **Use descriptive test names**
3. **Keep tests focused and isolated**
4. **Test edge cases and error conditions**
5. **Use proper assertions**
6. **Mock external dependencies**
7. **Clean up after tests**

### DO: Test Naming Convention
✅ **ALWAYS use descriptive test names**

```swift
// Good: Descriptive test names
@Test("User can successfully login with valid credentials")
func testSuccessfulLoginWithValidCredentials() { }

@Test("Error message is shown when login fails")
func testErrorMessageShownOnLoginFailure() { }

// Bad: Vague test names
@Test("Test login")
func testLogin() { }
```

## Anti-Patterns to Avoid

### DON'T: Common Testing Mistakes
❌ **NEVER test implementation details**
❌ **NEVER ignore async test patterns**
❌ **NEVER skip error condition testing**
❌ **NEVER use real network calls in tests**
❌ **NEVER ignore test isolation**
❌ **NEVER write tests that depend on external state**

### DON'T: Testing Anti-Patterns
❌ **NEVER use XCTest patterns in new projects**
❌ **NEVER test private methods directly**
❌ **NEVER ignore memory leak testing**
❌ **NEVER skip performance testing**
❌ **NEVER use hardcoded test data**