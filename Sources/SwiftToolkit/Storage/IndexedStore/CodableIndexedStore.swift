//
//  CodableIndexedStore.swift
//  SwiftToolkit
//
//  Generic file-per-item persistence with manifest indexing
//

import Foundation

/// Generic actor-based storage with file-per-item and manifest indexing
///
/// **Architecture**:
/// - Manifest/Index: `<namespace>.json` - Lightweight index for fast queries
/// - Items Folder: `<namespace>/` - One JSON file per item
/// - Thread-Safe: Actor isolation for concurrent access
/// - Event Stream: Real-time notifications of changes
///
/// **File Structure**:
/// ```
/// /Documents/BluetoothKit/
/// ├── PersistedDevice.json          # Index/manifest
/// └── PersistedDevice/              # Items folder
///     ├── 550e8400...json           # Individual items
///     ├── 7c9e6679...json
///     └── ...
/// ```
///
/// **Usage**:
/// ```swift
/// let store = try await CodableIndexedStore<PersistedDevice>(
///     directory: documentsURL.appendingPathComponent("BluetoothKit"),
///     namespace: "PersistedDevice",
///     filename: FilenameGenerator.uuid
/// )
///
/// // Add item
/// try await store.save(device)
///
/// // Query
/// let devices = try await store.fetchAll()
/// let device = try await store.fetch(id: uuid)
///
/// // Observe changes
/// for await event in store.events {
///     print("Store changed: \(event)")
/// }
/// ```
///
/// **Performance**:
/// - Write amplification: 99% reduction vs single-file (1.8KB vs 180KB)
/// - Fast queries: Index loaded in memory
/// - Lazy loading: Items loaded on-demand
/// - Concurrent-safe: Actor isolation prevents race conditions
public actor CodableIndexedStore<Item: CodableIndexedElement> {

    
    // MARK: - Types

    /// Filename generation closure
    public typealias FilenameGenerator = (Item.ID) -> String

    /// Event stream element type (for backward compatibility)
    public typealias StoreEvent = Event

    // MARK: - Properties

    /// Directory resolver (closure or direct URL)
    internal let directoryResolver: () throws -> URL

    /// Resolved directory URL (cached after first resolution)
    internal var resolvedDirectory: URL?

    /// Namespace for isolation
    internal let namespace: String

    /// Filename generator closure
    internal let filenameGenerator: FilenameGenerator

    /// Configuration
    internal let configuration: Configuration

    /// Debug settings
    internal let debugSettings: DebugSettings

    /// In-memory manifest (lazy loaded)
    internal var manifest: Manifest?

    /// In-memory cache (optional optimization)
    internal var cache: [Item.ID: Item] = [:]

    /// Event continuation for broadcasting changes
    internal var eventContinuation: AsyncStream<Event>.Continuation?

    /// File manager
    internal let fileManager = FileManager.default

    /// JSON encoder
    internal let encoder: JSONEncoder

    /// JSON decoder
    internal let decoder: JSONDecoder

    internal let logger: LoggerWrapper

    // MARK: - Computed Properties

    /// URL to manifest file: `<namespace>.json`
    internal var manifestURL: URL {
        guard let directory = resolvedDirectory else {
            // Fallback: try to resolve synchronously (may throw but better than crash)
            let dir = try! directoryResolver()
            return dir.appendingPathComponent("\(namespace).json")
        }
        return directory.appendingPathComponent("\(namespace).json")
    }

    /// URL to items folder: `<namespace>/`
    internal var itemsDirectory: URL {
        guard let directory = resolvedDirectory else {
            // Fallback: try to resolve synchronously (may throw but better than crash)
            let dir = try! directoryResolver()
            return dir.appendingPathComponent(namespace)
        }
        return directory.appendingPathComponent(namespace)
    }

    // MARK: - Initialization

    /// Initialize store with directory URL (lazy loading)
    ///
    /// **Parameters**:
    /// - `directory`: Base directory URL for store files
    /// - `namespace`: Namespace for isolation (creates `<namespace>.json` and `<namespace>/`)
    /// - `filename`: Closure to generate filename from item ID
    /// - `configuration`: Store behavior configuration
    /// - `debugSettings`: Debug/testing settings
    ///
    /// **Note**: Directory creation and manifest loading happen on first operation (lazy)
    public init(
        directory: URL,
        namespace: String,
        filename: @escaping FilenameGenerator,
        configuration: Configuration = Configuration(),
        debugSettings: DebugSettings = DebugSettings()
    ) {
        self.directoryResolver = { directory }
        self.namespace = namespace
        self.filenameGenerator = filename
        self.configuration = configuration
        self.debugSettings = debugSettings

        // Configure logger (prioritize custom, fallback to default)
        self.logger = configuration.logger ?? .init(
            logger: .init(subsystem: "com.bluetoothkit.store", category: namespace),
            prefix: "[CodableIndexedStore]",
            enabled: debugSettings.logOperations
        )

        // Configure encoder (prioritize custom, fallback to default)
        if let customEncoder = configuration.encoder {
            self.encoder = customEncoder
        } else {
            let defaultEncoder = JSONEncoder()
            if configuration.prettyPrintJSON {
                defaultEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            self.encoder = defaultEncoder
        }

        // Configure decoder (custom or default)
        self.decoder = configuration.decoder ?? JSONDecoder()

        // Manifest will be loaded lazily on first operation
        self.manifest = nil
    }

    /// Initialize store with LocalFileURL.Directory (lazy loading)
    ///
    /// **Parameters**:
    /// - `directory`: LocalFileURL.Directory object (calls getURL(createFolders: true) on first use)
    /// - `namespace`: Namespace for isolation
    /// - `filename`: Closure to generate filename from item ID
    /// - `configuration`: Store behavior configuration
    /// - `debugSettings`: Debug/testing settings
    ///
    /// **Note**: Directory creation and manifest loading happen on first operation (lazy)
    public init(
        directory: LocalFileURL.Directory,
        namespace: String,
        filename: @escaping FilenameGenerator,
        configuration: Configuration = Configuration(),
        debugSettings: DebugSettings = DebugSettings()
    ) {
        self.directoryResolver = { try directory.getURL(createFolders: true) }
        self.namespace = namespace
        self.filenameGenerator = filename
        self.configuration = configuration
        self.debugSettings = debugSettings

        // Configure logger (prioritize custom, fallback to default)
        self.logger = configuration.logger ?? .init(
            logger: .init(subsystem: "com.bluetoothkit.store", category: namespace),
            prefix: "[CodableIndexedStore]",
            enabled: debugSettings.logOperations
        )

        // Configure encoder (prioritize custom, fallback to default)
        if let customEncoder = configuration.encoder {
            self.encoder = customEncoder
        } else {
            let defaultEncoder = JSONEncoder()
            if configuration.prettyPrintJSON {
                defaultEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            self.encoder = defaultEncoder
        }

        // Configure decoder (custom or default)
        self.decoder = configuration.decoder ?? JSONDecoder()

        // Manifest will be loaded lazily on first operation
        self.manifest = nil
    }

    // MARK: - Lazy Initialization

    /// Ensure store is initialized (resolves directory and loads manifest)
    ///
    /// **Behavior**:
    /// - Resolves directory URL (once, cached)
    /// - Creates directory structure if needed
    /// - Loads or creates manifest
    /// - Validates namespace
    ///
    /// **Returns**: The initialized manifest
    ///
    /// **Thread-Safe**: Multiple concurrent calls are safe, initialization happens once
    @discardableResult
    internal func ensureInitialized() async throws -> Manifest {
        // Already initialized - return cached manifest
        if let manifest = manifest {
            return manifest
        }

        // Validate namespace
        guard !namespace.isEmpty else {
            throw IndexedStoreError.emptyNamespace
        }

        if configuration.validateFilenames {
            guard namespace.isSafeFilename() else {
                throw IndexedStoreError.unsafeNamespace(
                    namespace: namespace,
                    reason: "Contains unsafe characters"
                )
            }
        }

        // Resolve directory URL (once)
        let directory: URL
        if let resolved = resolvedDirectory {
            directory = resolved
        } else {
            directory = try directoryResolver()
            resolvedDirectory = directory
        }

        // Create directory structure (only in file mode)
        if configuration.storageMode == .file && configuration.autoCreateDirectory {
            try Self.createDirectoryStructure(
                directory: directory,
                namespace: namespace,
                fileManager: fileManager
            )
        }


        let manifest: Manifest

        // Load or create manifest
        if configuration.storageMode == .file {
            let manifestFileURL = directory.appendingPathComponent("\(namespace).json")
            manifest = try Self.loadOrCreateManifest(
                at: manifestFileURL,
                namespace: namespace,
                fileManager: fileManager,
                decoder: decoder,
                recreateOnDecodingError: configuration.recreateOnDecodingError,
                logger: logger
            )
        } else {
            // Memory mode: start with empty manifest
            manifest = .empty(namespace: namespace)
        }

        if debugSettings.logOperations {
            let location = configuration.storageMode == .file ? directory.path : "memory"
            self.logger.info("Initialized with namespace '\(namespace)' at '\(location)'")
        }
        self.manifest = manifest
        return manifest  // Safe unwrap - we just set it above
    }

}
