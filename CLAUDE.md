# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build & Test
```bash
swift build           # Build the package
swift test            # Run all tests
swift test --verbose  # Run tests with detailed output
```

### Package Management
```bash
swift package resolve         # Resolve dependencies
swift package show-dependencies  # Show dependency tree
swift package clean           # Clean build artifacts
```

## Architecture Overview

SwiftToolkit is a Swift Package Manager library providing foundational utilities organized into focused modules:

- **Async/**: Concurrency primitives (AsyncLock, AsyncThrottler, DebounceAsync)
- **Cancellation/**: Task management (AsyncCancelBag, CombineCancelBag) 
- **Storage/**: File persistence (StorageCodable for JSON storage)
- **Files/**: File system utilities (LocalFileURL with type safety)
- **Streams/**: Async stream utilities (MulticastAsyncStream)
- **Logging/**: Logging abstractions (LoggerWrapper)

### Key Architectural Patterns

1. **Actor-based Concurrency**: AsyncLock and AsyncCancelBag use Swift actors for thread-safe operations
2. **Generic Storage**: StorageCodable provides type-safe JSON persistence for any Codable type
3. **Async/Await First**: All utilities are designed around Swift's modern concurrency model
4. **Modular Design**: Each utility category is self-contained with minimal cross-dependencies

### Dependencies
- **AsyncAlgorithms**: Apple's async algorithm package (re-exported)
- **Swift Testing**: Modern testing framework (test target only)

### Platform Support
- iOS 15.0+ / macOS 15.0+
- Swift 6.1+
- Uses Swift's strict concurrency checking

### Testing Strategy
Uses Swift Testing framework with `@Test` and `@Suite` attributes. Tests cover:
- Thread safety of concurrent utilities
- Persistence correctness for storage utilities  
- Cancellation behavior for async operations
- Performance characteristics (throttling, debouncing)

Test files use temporary directories and UUID-based filenames to avoid conflicts.