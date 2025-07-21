# SwiftUI Performance Rules

## View Update Optimization

### DO: Minimize View Updates
✅ **ALWAYS use _printChanges() for performance debugging**

```swift
// Debug view updates
struct ContentView: View {
    @State private var counter = 0
    
    var body: some View {
        let _ = Self._printChanges()
        
        VStack {
            Text("Counter: \(counter)")
            Button("Increment") {
                counter += 1
            }
        }
    }
}
```

### DO: Optimize State Changes
✅ **ALWAYS minimize state that triggers view updates**

```swift
// Good: Separate state for different concerns
@Observable
class ViewModel {
    // UI state - triggers updates
    var isLoading = false
    var items: [Item] = []
    
    // Internal state - doesn't trigger updates
    private var cache: [String: Data] = [:]
    private var lastFetchTime: Date?
}

// Bad: Single state object that triggers unnecessary updates
@Observable
class BadViewModel {
    var state = AppState() // Changes to any property trigger full view update
}
```

### DO: Use Equatable for Performance
✅ **ALWAYS implement Equatable for model objects**

```swift
struct Item: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    
    // Equatable implementation helps SwiftUI optimize updates
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.description == rhs.description
    }
}
```

## Memory Management

### DO: Avoid Retain Cycles
✅ **ALWAYS use weak references in closures that capture self**

```swift
@Observable
class UserViewModel {
    var users: [User] = []
    
    func loadUsers() {
        DataService.shared.fetchUsers { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let users):
                self.users = users
            case .failure(let error):
                // Handle error
                break
            }
        }
    }
}
```

### DO: Proper Task Management
✅ **ALWAYS store and cancel tasks appropriately**

```swift
@Observable
class DataViewModel {
    private var loadingTask: Task<Void, Never>?
    
    func loadData() {
        // Cancel previous task
        loadingTask?.cancel()
        
        loadingTask = Task {
            do {
                let data = try await dataService.fetchData()
                if !Task.isCancelled {
                    self.data = data
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error
                }
            }
        }
    }
    
    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}
```

## GeometryReader Alternatives

### DO: Avoid GeometryReader When Possible
✅ **ALWAYS use modern alternatives to GeometryReader**

```swift
// Good: Use containerRelativeFrame
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
                .containerRelativeFrame(.horizontal) { width, axis in
                    width * 0.8
                }
        }
    }
}

// Good: Use ViewThatFits
ViewThatFits {
    HStack {
        // Full content
    }
    VStack {
        // Compact content
    }
}
```

❌ **NEVER use GeometryReader for simple sizing**

```swift
// Bad: Unnecessary GeometryReader
GeometryReader { geometry in
    Rectangle()
        .frame(width: geometry.size.width * 0.8)
}

// Good: Use frame with maxWidth
Rectangle()
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 40) // Achieves similar effect
```

### DO: Use ViewThatFits
✅ **ALWAYS use ViewThatFits for adaptive layouts**

```swift
// Adaptive button layout
ViewThatFits {
    HStack {
        Button("Cancel") { }
        Button("Save Changes") { }
        Button("Export Data") { }
    }
    
    VStack {
        Button("Cancel") { }
        Button("Save Changes") { }
        Button("Export Data") { }
    }
}
```

## List Performance

### DO: Optimize List Rendering
✅ **ALWAYS use LazyVStack/LazyHStack for large datasets**

```swift
// Good: Lazy loading for large lists
ScrollView {
    LazyVStack(spacing: 8) {
        ForEach(largeDataset) { item in
            ItemView(item: item)
        }
    }
    .padding()
}

// Good: Standard List for moderate datasets
List(items) { item in
    ItemRow(item: item)
}
```

### DO: Implement Proper List Sections
✅ **ALWAYS optimize sectioned lists**

```swift
// Good: Efficient sectioned list
List {
    ForEach(sections) { section in
        Section(section.title) {
            ForEach(section.items) { item in
                ItemRow(item: item)
            }
        }
    }
}

// Good: Lazy sectioned content
ScrollView {
    LazyVStack(pinnedViews: [.sectionHeaders]) {
        ForEach(sections) { section in
            Section {
                ForEach(section.items) { item in
                    ItemRow(item: item)
                }
            } header: {
                Text(section.title)
                    .font(.headline)
                    .padding()
                    .background(.regularMaterial)
            }
        }
    }
}
```

### DO: Optimize List Updates
✅ **ALWAYS use proper identifiers for list items**

```swift
// Good: Stable identifiers
struct Item: Identifiable {
    let id = UUID() // Stable identifier
    var title: String
    var isCompleted: Bool
}

// Good: Use of id for complex items
List(items) { item in
    ItemRow(item: item)
        .id(item.id) // Explicit ID when needed
}
```

## Animation Performance

### DO: Optimize Animations
✅ **ALWAYS use appropriate animation types**

```swift
// Good: Smooth animations with proper timing
@State private var isExpanded = false

var body: some View {
    VStack {
        DisclosureGroup("Details", isExpanded: $isExpanded) {
            DetailView()
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

// Good: Prefer implicit animations
Button("Toggle") {
    withAnimation(.spring()) {
        isVisible.toggle()
    }
}
```

### DO: Use Transaction Control
✅ **ALWAYS disable animations when needed**

```swift
// Disable animations for data updates
func updateData() {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    
    withTransaction(transaction) {
        self.data = newData
    }
}
```

## Image Loading and Caching

### DO: AsyncImage Best Practices
✅ **ALWAYS implement proper image loading**

```swift
// Good: AsyncImage with proper placeholder and error handling
AsyncImage(url: imageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 100, height: 100)
        .clipped()
} placeholder: {
    ProgressView()
        .frame(width: 100, height: 100)
}

// Good: Custom AsyncImage with caching
AsyncImage(url: imageURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    case .failure(_):
        Image(systemName: "photo")
            .foregroundColor(.secondary)
    @unknown default:
        EmptyView()
    }
}
```

### DO: Implement Image Caching
✅ **ALWAYS implement proper image caching strategy**

```swift
// Custom image cache
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
```

## Task and Async Performance

### DO: Optimize Async Operations
✅ **ALWAYS use task(id:) for reactive data loading**

```swift
// Good: Reactive data loading
.task(id: searchText) {
    await searchItems(query: searchText)
}

// Good: Proper task cancellation
.task {
    do {
        let data = try await longRunningOperation()
        if !Task.isCancelled {
            self.data = data
        }
    } catch {
        if !Task.isCancelled {
            self.error = error
        }
    }
}
```

### DO: Background Processing
✅ **ALWAYS perform heavy operations off the main thread**

```swift
@MainActor
@Observable
class DataProcessor {
    var processedData: [ProcessedItem] = []
    var isProcessing = false
    
    func processData(_ rawData: [RawItem]) {
        isProcessing = true
        
        Task.detached {
            // Heavy processing off main thread
            let processed = rawData.map { item in
                // Complex processing
                return ProcessedItem(from: item)
            }
            
            await MainActor.run {
                self.processedData = processed
                self.isProcessing = false
            }
        }
    }
}
```

## ScrollView Performance

### DO: Optimize ScrollView Content
✅ **ALWAYS use proper scroll view techniques**

```swift
// Good: Efficient scroll view with position tracking
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
                .onScrollVisibilityChange { isVisible in
                    if isVisible {
                        loadMoreIfNeeded(for: item)
                    }
                }
        }
    }
}
.scrollPosition($scrollPosition)
```

### DO: Implement Infinite Scroll
✅ **ALWAYS implement efficient infinite scrolling**

```swift
@Observable
class InfiniteScrollViewModel {
    var items: [Item] = []
    var isLoading = false
    var hasMoreItems = true
    
    func loadMoreItems() {
        guard !isLoading && hasMoreItems else { return }
        
        isLoading = true
        
        Task {
            do {
                let newItems = try await fetchMoreItems()
                items.append(contentsOf: newItems)
                hasMoreItems = newItems.count >= pageSize
            } catch {
                // Handle error
            }
            isLoading = false
        }
    }
}

// Usage
List(viewModel.items) { item in
    ItemRow(item: item)
        .onAppear {
            if item == viewModel.items.last {
                viewModel.loadMoreItems()
            }
        }
}
```

## Memory Usage Optimization

### DO: Optimize Large Data Sets
✅ **ALWAYS paginate large datasets**

```swift
@Observable
class PaginatedDataViewModel {
    var currentPage: [Item] = []
    var pageSize = 50
    var currentPageIndex = 0
    
    func loadPage(_ index: Int) {
        Task {
            let startIndex = index * pageSize
            let endIndex = min(startIndex + pageSize, totalItems.count)
            
            let pageItems = Array(totalItems[startIndex..<endIndex])
            
            await MainActor.run {
                self.currentPage = pageItems
                self.currentPageIndex = index
            }
        }
    }
}
```

### DO: Implement Data Cleanup
✅ **ALWAYS clean up unused data**

```swift
@Observable
class CacheManager {
    private var cache: [String: Any] = [:]
    private let maxCacheSize = 100
    
    func setValue(_ value: Any, forKey key: String) {
        if cache.count >= maxCacheSize {
            // Remove oldest entries
            let keysToRemove = cache.keys.prefix(10)
            keysToRemove.forEach { cache.removeValue(forKey: $0) }
        }
        
        cache[key] = value
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
```

## Performance Monitoring

### DO: Performance Debugging
✅ **ALWAYS monitor performance during development**

```swift
// Performance timing
func measurePerformance<T>(operation: () throws -> T) rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    
    print("Operation took \(timeElapsed) seconds")
    return result
}

// Usage
let result = measurePerformance {
    // Expensive operation
    return processLargeDataset()
}
```

### DO: Memory Monitoring
✅ **ALWAYS monitor memory usage**

```swift
// Memory usage tracking
func logMemoryUsage() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let memoryUsage = info.resident_size / 1024 / 1024 // MB
        print("Memory usage: \(memoryUsage) MB")
    }
}
```

## Anti-Patterns to Avoid

### DON'T: Performance Killers
❌ **NEVER use unnecessary GeometryReader**
❌ **NEVER ignore task cancellation**
❌ **NEVER load all data at once for large datasets**
❌ **NEVER use @State for expensive computations**
❌ **NEVER ignore memory cleanup**
❌ **NEVER use synchronous operations on main thread**

### DON'T: Common Performance Mistakes
❌ **NEVER create objects in view body**
❌ **NEVER use complex operations in computed properties**
❌ **NEVER ignore animation performance**
❌ **NEVER use retain cycles in ViewModels**
❌ **NEVER ignore scroll performance**