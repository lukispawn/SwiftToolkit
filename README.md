# SwiftToolkit

A comprehensive collection of Swift utilities for modern app development. SwiftToolkit provides foundational components and advanced state management solutions designed to be shared across multiple Swift projects.

## Quick Navigation

🚀 **[LoadableModel - State Management Framework](#loadablemodel---complete-guide)** - Advanced async data loading with SwiftUI integration  
📦 **[Core Utilities](#core-utilities)** - Async, storage, logging, and concurrency tools  
⚡ **[Installation](#installation)** - Swift Package Manager setup  
🏗️ **[Architecture](#architecture)** - Project structure and design patterns  

## Features

### 📊 State Management (LoadableModel) ⭐
- **LoadableElementStore**: Observable store for single data entities with loading states
- **LoadableCollectionStore**: Collection management with pagination and CRUD operations
- **LoadableState**: Unified loading state enum (notRequested, loading, loaded, failed)
- **Smart Loading**: Debouncing, retry mechanisms, and background refresh
- **SwiftUI Integration**: Native @Observable support for reactive UIs

### Core Utilities

#### 🔄 Async/Concurrency
- **AsyncLock**: Actor-based lock ensuring only one async operation runs at a time
- **AsyncThrottler**: Key-based throttling for async operations with configurable intervals
- **DebounceAsync**: Debouncing for async operations with cancellation support
- **AsyncChannel Extensions**: Convert between AsyncChannel and AsyncStream

#### ❌ Cancellation Management
- **AsyncCancelBag**: Actor-based container for managing Tasks and Combine cancellables
- **CombineCancelBag**: Combine-specific cancellation management

#### 💾 Storage & Files
- **StorageCodable**: JSON-based file storage for Codable types
- **LocalFileURL**: Type-safe file URL handling with directory management

#### 🌊 Streams & Publishers
- **MulticastAsyncStream**: Broadcasting async streams to multiple subscribers
- **AsyncSequencePublisher**: Bridge any AsyncSequence to Combine Publisher for SwiftUI integration
- **Publisher Extensions**: Native `.onReceive()` support for MulticastAsyncStream

#### 📝 Logging
- **LoggerWrapper**: Structured logging wrapper with prefixes

## Requirements

- iOS 17.0+ / macOS 15.0+
- Swift 6.1+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add SwiftToolkit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lukispawn/SwiftToolkit.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "SwiftToolkit",  // Core utilities
        "LoadableModel"  // State management (optional)
    ]
)
```

## Usage Examples

### LoadableModel - Complete Guide ⭐

LoadableModel provides sophisticated state management for asynchronous data loading with automatic retry, caching, and SwiftUI integration.

#### Basic Element Store
```swift
import LoadableModel

// User profile store with configuration
let profileStore = LoadableElementStore(
    operation: {
        let service = try await apiConnect.requireAuthenticatedService()
        return try await service.getProfile().user
    },
    initial: nil,
    configuration: .init(
        refreshInterval: 60 * 11,  // Auto-refresh every 11 minutes
        debug: true,
        prefix: "User profile"
    )
)
```

#### SwiftUI Integration Pattern
```swift
struct ProfileView: View {
    @State private var store = LoadableElementStore<User>(...)
    
    var body: some View {
        Group {
            switch store.loadState {
            case .notRequested, .loading:
                ProgressView("Loading profile...")
            case .loaded:
                if let user = store.data.value {
                    UserDetailView(user: user)
                }
            case .failed(let error):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Error loading profile")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        Task {
                            try? await store.refresh(setting: .init(
                                reason: "User retry", 
                                debounce: false
                            ))
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .task {
            await store.onTask()  // Trigger initial load
        }
    }
}
```

**[📖 See complete LoadableModel guide below](#loadablemodel---detailed-examples)**

---

## Core Utilities Examples

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

### AsyncSequencePublisher & SwiftUI Integration
```swift
import SwiftToolkit
import Combine

// Convert any AsyncSequence to Combine Publisher
let asyncStream = AsyncStream<String> { continuation in
    continuation.yield("Hello")
    continuation.yield("World")
    continuation.finish()
}

let publisher = Publishers.AsyncSequencePublisher(asyncStream)

// Use with SwiftUI .onReceive()
struct ContentView: View {
    @State private var receivedValues: [String] = []
    
    var body: some View {
        List(receivedValues, id: \.self) { value in
            Text(value)
        }
        .onReceive(publisher) { value in
            receivedValues.append(value)
        }
    }
}

// MulticastAsyncStream with native publisher support
let multicastStream = MulticastAsyncStream<String>()

struct LiveDataView: View {
    @State private var latestValue = ""
    
    var body: some View {
        Text("Latest: \(latestValue)")
            .onReceive(multicastStream.publisher()) { value in
                latestValue = value
            }
            .task {
                // Send values from elsewhere in your app
                await multicastStream.send("Real-time data")
            }
    }
}
```

### LoadableModel - Detailed Examples

#### Collection Store with CRUD Operations
```swift
// Media assets collection with full CRUD support
let mediasStore = LoadableCollectionStore<MediaAsset, String, String>(
    operation: {
        let service = try await apiConnect.requireAuthenticatedService()
        let items = try await service.send(APIRequests.MediaAsset.list).value
        return items.sorted(by: { $0.createdAt > $1.createdAt })
    },
    modifierService: DefaultCollectionModifier(
        refreshItem: { id in
            let service = try await apiConnect.requireAuthenticatedService()
            return try await service.send(APIRequests.MediaAsset.get(id: id)).value
        },
        removeItem: { id in
            let service = try await apiConnect.requireAuthenticatedService()
            try await service.send(APIRequests.MediaAsset.remove(id: id))
        }
    ),
    initial: nil,
    configuration: .init(
        refreshInterval: 60 * 11,
        debug: true,
        prefix: "Media assets"
    )
)

// Usage in SwiftUI
List(mediasStore.data.value ?? []) { mediaAsset in
    MediaAssetRow(mediaAsset: mediaAsset)
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                Task {
                    await mediasStore.removeItem(objectId: mediaAsset.id)
                }
            }
            Button("Refresh") {
                Task {
                    await mediasStore.refreshItem(objectId: mediaAsset.id)
                }
            }
        }
}
```

#### Advanced Configuration Patterns
```swift
// Frequent updates configuration
Configuration(
    refreshInterval: 30,             // Refresh every 30 seconds
    debounceReloadValue: 0.1,        // Fast debounce for real-time data
    debug: true,
    prefix: "LiveData"
)

// In-memory caching configuration
Configuration(
    refreshInterval: nil,            // No auto-refresh
    inMemory: true,                  // Cache permanently in memory
    debug: false
)

// High-frequency data configuration
Configuration(
    refreshInterval: 10,             // Very frequent updates
    debounceReloadValue: 0.5,        // Standard debounce
    debug: true,
    prefix: "RealTimeFeature"
)
```

#### Custom Service Providers

For complex loading logic or dependency injection, create custom services that conform to `LoadableElementProvider`:

```swift
// Protocol definition for type safety
protocol ProfileFetchServiceType: LoadableElementProvider where Model == UserDTO {}

// Custom service implementation
struct ProfileFetchService: ProfileFetchServiceType {
    let apiConnect: HomePhysioConnect
    
    func load() async throws -> UserDTO {
        let service = try await apiConnect.requireAuthenticatedService()
        return try await service.getProfile().user
    }
}

// Usage with custom service
let profileStore = LoadableElementStore(
    service: ProfileFetchService(apiConnect: apiConnect),
    initial: nil,
    configuration: .init(
        refreshInterval: 60 * 11,
        debug: true,
        prefix: "User profile"
    )
)
```

This pattern is ideal for:
- **Dependency injection**: Pass services/dependencies to the provider
- **Complex loading logic**: Multi-step data fetching or transformation
- **Reusable providers**: Share the same provider across multiple stores
- **Testing**: Easy to mock and test provider logic separately

#### Dynamic Source Updates
```swift
// Change data source dynamically
try await store.updateSource(operation: {
    try await newApiService.fetchData()
})

// Switch to constant value (useful for testing)
try await store.updateSource(constant: mockData)

// Switch to custom provider
try await store.updateSource(source: customDataProvider)
```

#### Error Handling Best Practices
```swift
// Safe refresh with error handling
private func safeRefresh(_ reason: String) async {
    do {
        try await store.refresh(setting: .init(
            reason: reason, 
            debounce: false,
            resetLast: true
        ))
    } catch {
        logger.error("Failed to refresh \(reason): \(error)")
        // Handle error appropriately
    }
}

// Handle authentication errors gracefully
let profileStore = LoadableElementStore<User?>(
    operation: {
        do {
            let service = try await apiConnect.requireAuthenticatedService()
            return try await service.getProfile().user
        } catch APIClientError.authenticationError(.missingAuthenticationData) {
            return nil  // Handle missing auth gracefully
        }
    },
    configuration: .init(debug: true, prefix: "Profile")
)
```

#### Observable and Reactive Patterns
```swift
// LoadableModel stores are @Observable - automatically update SwiftUI
@Observable
class MediaViewModel {
    let mediasStore: LoadableCollectionStore<MediaAsset, String, String>
    
    // Computed properties automatically trigger UI updates
    var isLoading: Bool { 
        mediasStore.loadState.isLoading() 
    }
    
    var mediaCount: Int { 
        mediasStore.data.value?.count ?? 0 
    }
    
    var hasError: Bool { 
        mediasStore.loadState.isError() 
    }
}

// SwiftUI automatically reacts to store changes
struct MediaListView: View {
    @State private var viewModel = MediaViewModel()
    
    var body: some View {
        NavigationStack {
            List(viewModel.mediasStore.data.value ?? []) { media in
                MediaRow(media: media)
            }
            .navigationTitle("Media (\(viewModel.mediaCount))")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

// Event-driven updates from external sources
func handleAuthenticationChange() async {
    // Stores automatically reflect new data when refreshed
    try? await profileStore.refresh(setting: .init(
        reason: "Authentication changed", 
        debounce: false
    ))
}

// Observe store events (advanced)
Task {
    for await event in await store.eventsSequence() {
        switch event {
        case .didFetch(let items):
            print("Fetched \(items.count) items")
        case .didUpdateState(let status):
            print("State changed to: \(status)")
        }
    }
}
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
├── Publishers/      # AsyncSequence to Combine Publisher bridges
└── Logging/         # Logging abstractions

LoadableModel/
├── Loadable Element/    # Single data entity management
├── Loadable Collection/ # Collection and pagination support
├── Helpers/            # Network reachability and extensions
├── LoadableState.swift  # Core loading state enum
└── LoadableModelType.swift # Protocol definitions
```

## Products

This package provides two separate products:

- **SwiftToolkit**: Core utilities for async operations, storage, and general-purpose tools
- **LoadableModel**: Advanced state management framework for data loading and UI integration

## Contributing

This package is designed as a foundational toolkit. When adding new utilities:

1. Choose the appropriate category folder
2. Add comprehensive documentation
3. Include usage examples in README
4. Consider thread safety and Swift concurrency best practices

## License

MIT License - see LICENSE file for details.

## Version

Current version: 1.3.0