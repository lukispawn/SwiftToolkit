# Documentation Standards Rules

## DocC Documentation

### DO: DocC Implementation
✅ **ALWAYS implement DocC documentation for public APIs**

```swift
import Foundation

/// A user management service that handles user operations.
///
/// The `UserService` provides methods for creating, retrieving, updating, and deleting users.
/// It follows the repository pattern and supports both local and remote data sources.
///
/// ## Usage
///
/// ```swift
/// let userService = UserService()
/// let users = try await userService.fetchUsers()
/// ```
///
/// ## Topics
///
/// ### Creating Users
/// - ``createUser(_:)``
/// - ``validateUser(_:)``
///
/// ### Retrieving Users
/// - ``fetchUsers()``
/// - ``fetchUser(id:)``
/// - ``searchUsers(query:)``
///
/// ### Updating Users
/// - ``updateUser(_:)``
/// - ``updateUserEmail(id:email:)``
///
/// ### Deleting Users
/// - ``deleteUser(id:)``
/// - ``deleteAllUsers()``
public class UserService {
    
    /// Creates a new user in the system.
    ///
    /// This method validates the user data before creation and ensures
    /// that the email address is unique across the system.
    ///
    /// - Parameter user: The user data to create. Must include a valid email address.
    /// - Returns: The created user with assigned ID.
    /// - Throws: `ValidationError` if the user data is invalid.
    /// - Throws: `NetworkError` if the creation fails due to network issues.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let newUser = User(name: "John Doe", email: "john@example.com")
    /// let createdUser = try await userService.createUser(newUser)
    /// print("Created user with ID: \(createdUser.id)")
    /// ```
    public func createUser(_ user: User) async throws -> User {
        // Implementation
        fatalError("Implementation needed")
    }
    
    /// Fetches all users from the system.
    ///
    /// This method retrieves all users with support for pagination and filtering.
    /// The results are sorted by creation date in descending order.
    ///
    /// - Returns: An array of users.
    /// - Throws: `NetworkError` if the fetch operation fails.
    ///
    /// > Important: This method may return a large number of users.
    /// > Consider using pagination for better performance.
    ///
    /// > Note: Users are cached locally for 5 minutes to improve performance.
    public func fetchUsers() async throws -> [User] {
        // Implementation
        fatalError("Implementation needed")
    }
}
```

### DO: Documentation Comments Structure
✅ **ALWAYS follow consistent documentation comment structure**

```swift
/// Brief description of the method or type.
///
/// Detailed description explaining the purpose, behavior, and any important
/// implementation details. This should be comprehensive enough for users
/// to understand how to use the API effectively.
///
/// ## Subsection Title (if needed)
///
/// Additional details organized under subsections.
///
/// - Parameter paramName: Description of the parameter.
/// - Returns: Description of the return value.
/// - Throws: Description of possible errors.
///
/// ## Example
///
/// ```swift
/// // Example usage code
/// ```
///
/// > Warning: Important warnings about usage.
/// > Note: Additional notes or tips.
/// > Important: Critical information users must know.
```

## Code Comments

### DO: Inline Comments
✅ **ALWAYS provide meaningful inline comments for complex logic**

```swift
class DataProcessor {
    func processUserData(_ users: [User]) -> [ProcessedUser] {
        return users.compactMap { user in
            // Skip users without valid email addresses
            guard isValidEmail(user.email) else {
                return nil
            }
            
            // Apply business rules for user processing
            var processedUser = ProcessedUser(from: user)
            
            // Calculate user score based on activity and engagement
            // Score ranges from 0-100, where 100 is highest engagement
            let activityScore = calculateActivityScore(user.activities)
            let engagementScore = calculateEngagementScore(user.interactions)
            processedUser.score = (activityScore + engagementScore) / 2
            
            return processedUser
        }
    }
    
    private func calculateActivityScore(_ activities: [Activity]) -> Double {
        // Weight recent activities more heavily
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
        
        let recentActivities = activities.filter { $0.timestamp > thirtyDaysAgo }
        let totalActivities = activities.count
        
        // Formula: (recent_activities / total_activities) * 100
        // Ensures users with recent activity get higher scores
        return totalActivities > 0 ? Double(recentActivities.count) / Double(totalActivities) * 100 : 0
    }
}
```

### DO: MARK Comments
✅ **ALWAYS use MARK comments for code organization**

```swift
class UserViewController: UIViewController {
    
    // MARK: - Properties
    
    private let viewModel: UserViewModel
    private var users: [User] = []
    
    // MARK: - Initialization
    
    init(viewModel: UserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUsers()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "Users"
        view.backgroundColor = .systemBackground
        setupTableView()
        setupConstraints()
    }
    
    private func setupTableView() {
        // Table view setup
    }
    
    private func setupConstraints() {
        // Constraints setup
    }
    
    // MARK: - Data Loading
    
    private func loadUsers() {
        // Data loading logic
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        // Refresh action
    }
    
    @objc private func addButtonTapped() {
        // Add action
    }
    
    // MARK: - Private Methods
    
    private func bindViewModel() {
        // ViewModel binding
    }
}
```

## README Documentation

### DO: Comprehensive README
✅ **ALWAYS create comprehensive README files**

```markdown
# Project Name

Brief description of what the project does and its main purpose.

## Features

- ✅ Feature 1 with brief description
- ✅ Feature 2 with brief description
- ✅ Feature 3 with brief description
- 🚧 Feature 4 (in development)

## Requirements

- iOS 18.0+ / macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/username/project.git", from: "1.0.0")
]
```

### Manual Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run

## Quick Start

```swift
import ProjectName

// Basic usage example
let manager = ProjectManager()
let result = await manager.performOperation()
```

## Documentation

- [API Documentation](https://docs.example.com)
- [User Guide](docs/user-guide.md)
- [Migration Guide](docs/migration.md)

## Architecture

This project follows MVVM architecture with the following structure:

```
Sources/
├── Models/          # Data models
├── ViewModels/      # Business logic
├── Views/           # SwiftUI views
├── Services/        # API and data services
└── Utilities/       # Helper utilities
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```

## API Documentation

### DO: API Documentation Standards
✅ **ALWAYS document API endpoints comprehensively**

```swift
/// API endpoint for user management operations.
///
/// This endpoint provides full CRUD operations for user entities.
/// All operations require authentication via Bearer token.
///
/// ## Authentication
///
/// ```
/// Authorization: Bearer <token>
/// ```
///
/// ## Rate Limiting
///
/// - 100 requests per minute per API key
/// - 1000 requests per hour per API key
///
/// ## Error Responses
///
/// All endpoints return standard HTTP status codes:
/// - `200`: Success
/// - `400`: Bad Request - Invalid input
/// - `401`: Unauthorized - Invalid or missing token
/// - `403`: Forbidden - Insufficient permissions
/// - `404`: Not Found - Resource not found
/// - `500`: Internal Server Error
///
/// Error response format:
/// ```json
/// {
///   "error": {
///     "code": "VALIDATION_ERROR",
///     "message": "Invalid email format",
///     "details": {
///       "field": "email",
///       "value": "invalid-email"
///     }
///   }
/// }
/// ```
enum UserEndpoint {
    /// Get all users
    ///
    /// **GET** `/api/v1/users`
    ///
    /// **Query Parameters:**
    /// - `page`: Page number (default: 1)
    /// - `limit`: Items per page (default: 20, max: 100)
    /// - `search`: Search term for name or email
    /// - `sort`: Sort field (`name`, `email`, `created_at`)
    /// - `order`: Sort order (`asc`, `desc`)
    ///
    /// **Response:**
    /// ```json
    /// {
    ///   "users": [
    ///     {
    ///       "id": "123",
    ///       "name": "John Doe",
    ///       "email": "john@example.com",
    ///       "created_at": "2023-01-01T00:00:00Z"
    ///     }
    ///   ],
    ///   "pagination": {
    ///     "page": 1,
    ///     "limit": 20,
    ///     "total": 100,
    ///     "pages": 5
    ///   }
    /// }
    /// ```
    case getAllUsers
    
    /// Get user by ID
    ///
    /// **GET** `/api/v1/users/{id}`
    ///
    /// **Path Parameters:**
    /// - `id`: User ID (UUID format)
    ///
    /// **Response:**
    /// ```json
    /// {
    ///   "id": "123",
    ///   "name": "John Doe",
    ///   "email": "john@example.com",
    ///   "created_at": "2023-01-01T00:00:00Z"
    /// }
    /// ```
    case getUser(id: String)
}
```

## Changelog Documentation

### DO: Changelog Maintenance
✅ **ALWAYS maintain a comprehensive changelog**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature X for better user experience
- Support for new iOS 18 APIs

### Changed
- Improved performance of data loading by 30%
- Updated UI to follow iOS 18 design guidelines

### Fixed
- Fixed crash when loading large datasets
- Resolved memory leak in image caching

## [2.1.0] - 2024-01-15

### Added
- Dark mode support
- iPad multitasking support
- Offline mode for core features
- New user onboarding flow

### Changed
- Migrated to SwiftUI 5.0
- Updated minimum iOS version to 17.0
- Improved accessibility support

### Deprecated
- Legacy authentication method (will be removed in 3.0.0)

### Fixed
- Fixed issue with search not working on iOS 17
- Resolved layout issues on iPhone SE

## [2.0.0] - 2023-12-01

### Added
- Complete rewrite in SwiftUI
- New MVVM architecture
- Comprehensive test suite
- CI/CD pipeline

### Changed
- **BREAKING**: New API structure
- **BREAKING**: Minimum iOS version now 16.0
- Improved performance across all features

### Removed
- **BREAKING**: Removed UIKit components
- **BREAKING**: Removed legacy networking layer

### Fixed
- All known issues from v1.x series

## [1.2.1] - 2023-10-15

### Fixed
- Critical security vulnerability in authentication
- Fixed crash on iOS 15 devices

## [1.2.0] - 2023-10-01

### Added
- Push notifications support
- Export functionality
- Advanced search filters

### Fixed
- Fixed sync issues
- Improved error handling
```

## Code Documentation Guidelines

### DO: Documentation Best Practices
✅ **ALWAYS follow documentation best practices**

```swift
// Good: Clear, comprehensive documentation
/// Authenticates a user with the provided credentials.
///
/// This method validates the credentials against the authentication server
/// and returns a JWT token upon successful authentication. The token
/// should be stored securely and included in subsequent API requests.
///
/// - Parameters:
///   - email: The user's email address. Must be a valid email format.
///   - password: The user's password. Must be at least 8 characters long.
/// - Returns: An authentication token that expires after 24 hours.
/// - Throws: `AuthenticationError.invalidCredentials` if credentials are invalid.
/// - Throws: `NetworkError` if the authentication request fails.
///
/// ## Example
///
/// ```swift
/// do {
///     let token = try await authService.authenticate(
///         email: "user@example.com",
///         password: "securePassword123"
///     )
///     UserDefaults.standard.set(token, forKey: "authToken")
/// } catch AuthenticationError.invalidCredentials {
///     showInvalidCredentialsAlert()
/// } catch {
///     showNetworkErrorAlert()
/// }
/// ```
///
/// > Warning: Never log or store the password in plain text.
/// > Always use secure storage mechanisms for sensitive data.
func authenticate(email: String, password: String) async throws -> String {
    // Implementation
}

// Bad: Minimal or unclear documentation
/// Authenticates user
func authenticate(email: String, password: String) async throws -> String {
    // Implementation
}
```

## Testing Documentation

### DO: Test Documentation
✅ **ALWAYS document test cases and scenarios**

```swift
/// Test suite for UserService authentication functionality.
///
/// This suite covers all authentication scenarios including:
/// - Valid credentials
/// - Invalid credentials
/// - Network failures
/// - Token expiration
/// - Rate limiting
///
/// ## Test Data
///
/// The tests use the following test accounts:
/// - `test@example.com` / `password123` - Valid account
/// - `invalid@example.com` / `wrongpass` - Invalid account
/// - `blocked@example.com` / `password123` - Blocked account
@Suite("Authentication Tests")
struct AuthenticationTests {
    
    /// Test successful authentication with valid credentials.
    ///
    /// **Given:** Valid email and password
    /// **When:** Authentication is attempted
    /// **Then:** A valid JWT token is returned
    /// **And:** The token contains correct user information
    @Test("Valid credentials return authentication token")
    func testValidCredentialsAuthentication() async throws {
        // Arrange
        let authService = AuthService()
        let email = "test@example.com"
        let password = "password123"
        
        // Act
        let token = try await authService.authenticate(
            email: email,
            password: password
        )
        
        // Assert
        #expect(!token.isEmpty)
        #expect(token.contains(".")) // JWT format check
        
        // Verify token contains user information
        let decodedToken = try JWTDecoder().decode(token)
        #expect(decodedToken.email == email)
    }
    
    /// Test authentication failure with invalid credentials.
    ///
    /// **Given:** Invalid email or password
    /// **When:** Authentication is attempted
    /// **Then:** AuthenticationError.invalidCredentials is thrown
    /// **And:** No token is returned
    @Test("Invalid credentials throw authentication error")
    func testInvalidCredentialsThrowError() async throws {
        // Arrange
        let authService = AuthService()
        let email = "invalid@example.com"
        let password = "wrongpass"
        
        // Act & Assert
        await #expect(throws: AuthenticationError.invalidCredentials) {
            try await authService.authenticate(
                email: email,
                password: password
            )
        }
    }
}
```

## Documentation Architecture

### DO: Documentation Structure
✅ **ALWAYS organize documentation systematically**

```
Documentation/
├── README.md                 # Project overview
├── CHANGELOG.md             # Version history
├── CONTRIBUTING.md          # Contribution guidelines
├── LICENSE                  # License information
├── docs/
│   ├── getting-started.md   # Quick start guide
│   ├── architecture.md      # Technical architecture
│   ├── api-reference.md     # API documentation
│   ├── user-guide.md        # End-user documentation
│   ├── migration/
│   │   ├── v1-to-v2.md     # Migration guides
│   │   └── v2-to-v3.md
│   ├── examples/
│   │   ├── basic-usage.md   # Code examples
│   │   └── advanced-usage.md
│   └── troubleshooting.md   # Common issues
└── .github/
    ├── ISSUE_TEMPLATE.md    # Issue templates
    └── PULL_REQUEST_TEMPLATE.md
```

## Documentation Quality Gates

### DO: Documentation Review Process
✅ **ALWAYS implement documentation quality gates**

```swift
// Documentation checklist for code reviews:
//
// [ ] All public APIs have comprehensive DocC documentation
// [ ] Complex algorithms have inline comments explaining logic
// [ ] README is up to date with latest features
// [ ] API changes are documented in CHANGELOG
// [ ] Breaking changes are clearly marked
// [ ] Code examples compile and run correctly
// [ ] Documentation follows consistent style
// [ ] All acronyms and technical terms are explained
// [ ] Links to external documentation are valid
// [ ] Screenshots and diagrams are current
```

## Anti-Patterns to Avoid

### DON'T: Documentation Mistakes
❌ **NEVER skip documentation for public APIs**
❌ **NEVER use outdated code examples**
❌ **NEVER ignore documentation in code reviews**
❌ **NEVER use unclear or ambiguous language**
❌ **NEVER skip changelog updates**
❌ **NEVER document implementation details in public APIs**

### DON'T: Common Documentation Errors
❌ **NEVER copy-paste documentation without updating**
❌ **NEVER use generic placeholder text**
❌ **NEVER ignore documentation warnings**
❌ **NEVER skip examples in complex APIs**
❌ **NEVER use internal terminology in public docs**

## Documentation Tools Integration

### DO: Automated Documentation
✅ **ALWAYS integrate documentation tools**

```swift
// Build script for generating documentation
#!/bin/bash

# Generate DocC documentation
xcodebuild docbuild \
    -scheme MyApp \
    -destination platform=iOS\ Simulator,name=iPhone\ 15\ Pro \
    -derivedDataPath ./DerivedData

# Export documentation archive
xcodebuild -create-xcframework \
    -archive ./DerivedData/Build/Products/Debug-iphonesimulator/MyApp.framework \
    -output ./Documentation/MyApp.xcframework

# Generate static documentation website
docc convert Sources/MyApp/MyApp.docc \
    --fallback-display-name MyApp \
    --fallback-bundle-identifier com.company.myapp \
    --fallback-bundle-version 1.0.0 \
    --output-path ./Documentation/Web
```

## Documentation Maintenance

### DO: Regular Documentation Updates
✅ **ALWAYS keep documentation current**

```swift
// Documentation maintenance schedule:
//
// Daily:
// - Review and update inline comments for new code
// - Update README for new features
//
// Weekly:
// - Review and update API documentation
// - Check for broken links in documentation
//
// Monthly:
// - Review entire documentation structure
// - Update architecture documentation
// - Clean up outdated examples
//
// Per Release:
// - Update CHANGELOG with all changes
// - Update version numbers in documentation
// - Review and update migration guides
// - Generate and publish API documentation
```