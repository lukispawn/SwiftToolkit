/// SwiftToolkit - A comprehensive collection of Swift utilities for modern app development
///
/// This package provides foundational utilities for:
/// - **Async/Concurrency**: Advanced async patterns like locks, throttling, and debouncing
/// - **Cancellation Management**: Actor-based cancel bags for managing async tasks
/// - **Storage**: Type-safe JSON file storage for Codable types
/// - **File Utilities**: Safe file URL handling with directory management
/// - **Streams**: Multicast async streams for broadcasting events
/// - **Logging**: Wrapper utilities for structured logging
///
/// Designed as a foundational package to be shared across multiple Swift projects.

@_exported import AsyncAlgorithms

// MARK: - Version
public enum SwiftToolkit {
    public static let version = "1.1.0"
    public static let name = "SwiftToolkit"
}