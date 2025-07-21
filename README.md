# SwiftToolkit

A comprehensive collection of Swift utilities for modern app development. SwiftToolkit provides foundational components designed to be shared across multiple Swift projects.

## Features

### 🔄 Async/Concurrency
- **AsyncLock**: Actor-based lock ensuring only one async operation runs at a time
- **AsyncThrottler**: Key-based throttling for async operations with configurable intervals
- **DebounceAsync**: Debouncing for async operations with cancellation support
- **AsyncChannel Extensions**: Convert between AsyncChannel and AsyncStream

### ❌ Cancellation Management
- **AsyncCancelBag**: Actor-based container for managing Tasks and Combine cancellables
- **CombineCancelBag**: Combine-specific cancellation management

### 💾 Storage & Files
- **StorageCodable**: JSON-based file storage for Codable types
- **LocalFileURL**: Type-safe file URL handling with directory management

### 🌊 Streams
- **MulticastAsyncStream**: Broadcasting async streams to multiple subscribers

### 📝 Logging
- **LoggerWrapper**: Structured logging wrapper with prefixes

## Requirements

- iOS 15.0+ / macOS 15.0+
- Swift 6.1+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add SwiftToolkit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lukispawn/SwiftToolkit.git", from: "0.1.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftToolkit"]
)
```

## Usage Examples

### AsyncLock
```swift
import SwiftToolkit

let lock = AsyncLock()

Task {
    await lock.withLock {
        // Only one task can execute this block at a time
        await someAsyncOperation()
    }
}
```

### AsyncThrottler
```swift
let throttler = AsyncThrottler()

// This will throttle calls by key, allowing max one call per second
await throttler.throttle(key: "api-call", interval: 1.0) {
    await callAPI()
}
```

### StorageCodable
```swift
struct UserSettings: Codable {
    let theme: String
    let notifications: Bool
}

let storage = StorageCodable<UserSettings>(
    filename: "user-settings.json",
    directory: .documentDirectory
)

// Save settings
try await storage.save(UserSettings(theme: "dark", notifications: true))

// Load settings
let settings = try await storage.load()
```

### AsyncCancelBag
```swift
let cancelBag = AsyncCancelBag()

// Add tasks that will be cancelled together
await cancelBag.addTask {
    // Long running task
}

await cancelBag.addCancellable(publisher.sink { _ in })

// Cancel all tasks and subscriptions
await cancelBag.cancelAll()
```

## Architecture

SwiftToolkit is organized into focused modules:

```
SwiftToolkit/
├── Async/           # Concurrency utilities
├── Cancellation/    # Task and subscription management
├── Storage/         # File and data persistence
├── Files/           # File system utilities
├── Streams/         # Async stream utilities
└── Logging/         # Logging abstractions
```

## Contributing

This package is designed as a foundational toolkit. When adding new utilities:

1. Choose the appropriate category folder
2. Add comprehensive documentation
3. Include usage examples in README
4. Consider thread safety and Swift concurrency best practices

## License

MIT License - see LICENSE file for details.

## Version

Current version: 0.1.0