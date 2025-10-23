//
//  CodableIndexedStoreTests.swift
//  SwiftToolkit
//
//  Tests for CodableIndexedStore generic persistence layer
//

import Testing
import Foundation
@testable import SwiftToolkit

// MARK: - Test Models

/// Simple test model for basic store operations
struct TestUser: CodableIndexedElement {
    let id: UUID
    var name: String
    var email: String
    var age: Int
}

/// Test model with String ID
struct TestDevice: CodableIndexedElement {
    let id: String
    var model: String
    var serialNumber: String
}

// MARK: - Store Initialization Tests

@Suite("CodableIndexedStore - Initialization")
struct StoreInitializationTests {

    @Test("Store initializes successfully with valid namespace")
    func initializationSuccess() async throws {
        // Given: Valid configuration
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let namespace = "TestUsers"

        // When: Creating store
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )

        // Then: Store should be initialized
        let count = await store.count
        #expect(count == 0)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Store creates directory structure automatically")
    func directoryCreation() async throws {
        // Given: Non-existent directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let namespace = "TestUsers"

        // When: Creating store with autoCreateDirectory enabled
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )

        try await store.ensureInitialized()
        
        // Then: Directory and namespace folder should exist
        #expect(FileManager.default.fileExists(atPath: tempDir.path))

        let namespaceDir = tempDir.appendingPathComponent(namespace)
        #expect(FileManager.default.fileExists(atPath: namespaceDir.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
        _ = store // Silence unused warning
    }

    @Test("Store throws error for empty namespace")
    func emptyNamespaceError() async throws {
        // Given: Empty namespace
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: "",
            filename: { id in "\(id.uuidString).json" }
        )

        // When/Then: First operation should throw validation error
        await #expect(throws: IndexedStoreError.self) {
            try await store.fetchAll()
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Store validates unsafe namespace characters")
    func unsafeNamespaceValidation() async throws {
        // Given: Namespace with path traversal
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: "../dangerous",
            filename: { id in "\(id.uuidString).json" }
        )

        // When/Then: First operation should throw validation error
        await #expect(throws: IndexedStoreError.self) {
            try await store.fetchAll()
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - CRUD Operations Tests

@Suite("CodableIndexedStore - CRUD Operations")
struct CRUDOperationsTests {

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let namespace = "TestUsers"

    @Test("Save creates new item successfully")
    func saveNewItem() async throws {
        // Given: Empty store
        let store = try await createStore()
        defer { cleanup() }

        let user = TestUser(id: UUID(), name: "Alice", email: "alice@example.com", age: 30)

        // When: Saving item
        let saved = try await store.save(user)

        // Then: Item should be saved
        #expect(saved.id == user.id)
        #expect(await store.count == 1)
        #expect(await store.contains(id: user.id))
    }

    @Test("Save updates existing item")
    func saveUpdateItem() async throws {
        // Given: Store with existing item
        let store = try await createStore()
        defer { cleanup() }

        var user = TestUser(id: UUID(), name: "Bob", email: "bob@example.com", age: 25)
        _ = try await store.save(user)

        // When: Updating item
        user.email = "bob.updated@example.com"
        user.age = 26
        _ = try await store.save(user)

        // Then: Item should be updated
        let fetched = try await store.fetch(id: user.id)
        #expect(fetched.email == "bob.updated@example.com")
        #expect(fetched.age == 26)
        #expect(await store.count == 1) // No duplicate
    }

    @Test("Fetch retrieves item by ID")
    func fetchItem() async throws {
        // Given: Store with item
        let store = try await createStore()
        defer { cleanup() }

        let user = TestUser(id: UUID(), name: "Charlie", email: "charlie@example.com", age: 35)
        _ = try await store.save(user)

        // When: Fetching item
        let fetched = try await store.fetch(id: user.id)

        // Then: Should return correct item
        #expect(fetched.id == user.id)
        #expect(fetched.name == "Charlie")
        #expect(fetched.email == "charlie@example.com")
        #expect(fetched.age == 35)
    }

    @Test("Fetch throws error for non-existent item")
    func fetchNonExistentItem() async throws {
        // Given: Empty store
        let store = try await createStore()
        defer { cleanup() }

        let nonExistentID = UUID()

        // When/Then: Fetching should throw
        await #expect(throws: IndexedStoreError.self) {
            _ = try await store.fetch(id: nonExistentID)
        }
    }

    @Test("FetchAll returns all items")
    func fetchAllItems() async throws {
        // Given: Store with multiple items
        let store = try await createStore()
        defer { cleanup() }

        let users = [
            TestUser(id: UUID(), name: "User1", email: "user1@example.com", age: 20),
            TestUser(id: UUID(), name: "User2", email: "user2@example.com", age: 30),
            TestUser(id: UUID(), name: "User3", email: "user3@example.com", age: 40)
        ]

        for user in users {
            _ = try await store.save(user)
        }

        // When: Fetching all
        let fetched = try await store.fetchAll()

        // Then: Should return all items
        #expect(fetched.count == 3)

        let fetchedIDs = Set(fetched.map(\.id))
        let originalIDs = Set(users.map(\.id))
        #expect(fetchedIDs == originalIDs)
    }

    @Test("Remove deletes item successfully")
    func removeItem() async throws {
        // Given: Store with item
        let store = try await createStore()
        defer { cleanup() }

        let user = TestUser(id: UUID(), name: "David", email: "david@example.com", age: 28)
        _ = try await store.save(user)

        #expect(await store.count == 1)

        // When: Removing item
        let removed = try await store.remove(id: user.id)

        // Then: Item should be removed
        #expect(removed.id == user.id)
        #expect(await store.count == 0)
        #expect(await store.contains(id: user.id) == false)
    }

    @Test("Remove throws error for non-existent item")
    func removeNonExistentItem() async throws {
        // Given: Empty store
        let store = try await createStore()
        defer { cleanup() }

        let nonExistentID = UUID()

        // When/Then: Removing should throw
        await #expect(throws: IndexedStoreError.self) {
            _ = try await store.remove(id: nonExistentID)
        }
    }

    @Test("RemoveAll clears entire store")
    func removeAllItems() async throws {
        // Given: Store with multiple items
        let store = try await createStore()
        defer { cleanup() }

        for i in 1...5 {
            let user = TestUser(id: UUID(), name: "User\(i)", email: "user\(i)@example.com", age: 20 + i)
            _ = try await store.save(user)
        }

        #expect(await store.count == 5)

        // When: Removing all
        try await store.removeAll()

        // Then: Store should be empty
        #expect(await store.count == 0)
        let all = try await store.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - Helpers

    private func createStore() async throws -> CodableIndexedStore<TestUser> {
        CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Persistence Tests

@Suite("CodableIndexedStore - Persistence")
struct PersistenceTests {

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let namespace = "PersistenceTest"

    @Test("Items persist across store instances")
    func itemsPersist() async throws {
        defer { cleanup() }

        let userID = UUID()
        let user = TestUser(id: userID, name: "Persistent", email: "persist@example.com", age: 40)

        // Given: Save item and dispose store
        do {
            let store = try await createStore()
            _ = try await store.save(user)
        }

        // When: Creating new store instance
        let newStore = try await createStore()

        // Then: Item should still exist
        let fetched = try await newStore.fetch(id: userID)
        #expect(fetched.id == userID)
        #expect(fetched.name == "Persistent")
        #expect(fetched.email == "persist@example.com")
    }

    @Test("Index file exists after save")
    func indexFileExists() async throws {
        defer { cleanup() }

        // Given: Store with saved item
        let store = try await createStore()
        let user = TestUser(id: UUID(), name: "Test", email: "test@example.com", age: 25)
        _ = try await store.save(user)

        // Then: Index file should exist
        let indexPath = tempDir.appendingPathComponent("\(namespace).json")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))
    }

    @Test("Item file exists after save")
    func itemFileExists() async throws {
        defer { cleanup() }

        // Given: Store with saved item
        let store = try await createStore()
        let user = TestUser(id: UUID(), name: "Test", email: "test@example.com", age: 25)
        _ = try await store.save(user)

        // Then: Item file should exist in namespace folder
        let itemsDir = tempDir.appendingPathComponent(namespace)
        let itemFile = itemsDir.appendingPathComponent("\(user.id.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: itemFile.path))
    }

    @Test("Updating item modifies file without creating duplicate")
    func updateModifiesFileInPlace() async throws {
        defer { cleanup() }

        // Given: Store with item
        let store = try await createStore()
        var user = TestUser(id: UUID(), name: "Original", email: "original@example.com", age: 30)
        _ = try await store.save(user)

        let itemsDir = tempDir.appendingPathComponent(namespace)
        let beforeUpdate = try FileManager.default.contentsOfDirectory(atPath: itemsDir.path)

        // When: Updating item
        user.name = "Updated"
        _ = try await store.save(user)

        // Then: Should have same number of files (no duplicate)
        let afterUpdate = try FileManager.default.contentsOfDirectory(atPath: itemsDir.path)
        #expect(beforeUpdate.count == afterUpdate.count)
        #expect(afterUpdate.count == 1)
    }

    // MARK: - Helpers

    private func createStore() async throws -> CodableIndexedStore<TestUser> {
        CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Namespace Isolation Tests

@Suite("CodableIndexedStore - Namespace Isolation")
struct NamespaceIsolationTests {

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    @Test("Multiple stores can share same directory with different namespaces")
    func multipleNamespaces() async throws {
        defer { cleanup() }

        // Given: Two stores with different namespaces in same directory
        let usersStore = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: "Users",
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )

        let devicesStore = CodableIndexedStore<TestDevice>(
            directory: tempDir,
            namespace: "Devices",
            filename: { id in "\(id).json" },
            configuration: CodableIndexedStore<TestDevice>.Configuration(autoCreateDirectory: true)
        )

        // When: Saving to both stores
        let user = TestUser(id: UUID(), name: "User1", email: "user1@example.com", age: 25)
        let device = TestDevice(id: "device-123", model: "iPhone", serialNumber: "SN123")

        _ = try await usersStore.save(user)
        _ = try await devicesStore.save(device)

        // Then: Both stores should have their own data isolated
        #expect(await usersStore.count == 1)
        #expect(await devicesStore.count == 1)

        // Verify separate index files exist
        let usersIndex = tempDir.appendingPathComponent("Users.json")
        let devicesIndex = tempDir.appendingPathComponent("Devices.json")

        #expect(FileManager.default.fileExists(atPath: usersIndex.path))
        #expect(FileManager.default.fileExists(atPath: devicesIndex.path))

        // Verify separate folders exist
        let usersFolder = tempDir.appendingPathComponent("Users")
        let devicesFolder = tempDir.appendingPathComponent("Devices")

        #expect(FileManager.default.fileExists(atPath: usersFolder.path))
        #expect(FileManager.default.fileExists(atPath: devicesFolder.path))
    }

    @Test("Namespace data does not leak between stores")
    func noDataLeakage() async throws {
        defer { cleanup() }

        // Given: Two stores with different namespaces
        let store1 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: "Store1",
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )

        let store2 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: "Store2",
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )

        // When: Saving to store1 only
        let user = TestUser(id: UUID(), name: "Isolated", email: "isolated@example.com", age: 30)
        _ = try await store1.save(user)

        // Then: store2 should remain empty
        #expect(await store1.count == 1)
        #expect(await store2.count == 0)
        #expect(await store2.contains(id: user.id) == false)
    }

    // MARK: - Helpers

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Filename Security Tests

@Suite("CodableIndexedStore - Filename Security")
struct FilenameSecurityTests {

    @Test("Safe filename helper removes path traversal")
    func pathTraversalRemoval() {
        // Given: Dangerous filename with path traversal
        let dangerous = "../../../etc/passwd"

        // When: Sanitizing
        let safe = dangerous.makeSafeFilename()

        // Then: Should remove path traversal
        #expect(!safe.contains(".."))
        #expect(!safe.contains("/"))
    }

    @Test("Safe filename helper removes null bytes")
    func nullByteRemoval() {
        // Given: Filename with null byte
        let dangerous = "file\0name"

        // When: Sanitizing
        let safe = dangerous.makeSafeFilename()

        // Then: Should remove null byte
        #expect(!safe.contains("\0"))
    }

    @Test("Safe filename helper handles Windows reserved names")
    func windowsReservedNames() {
        // Given: Windows reserved name
        #if os(Windows)
        let reserved = "CON"

        // When: Sanitizing
        let safe = reserved.makeSafeFilename()

        // Then: Should modify reserved name
        #expect(safe != "CON")
        #expect(safe.contains("CON"))
        #endif
    }

    @Test("Safe filename validation detects unsafe filenames")
    func unsafeDetection() {
        // Given: Various filenames
        let safe = "MyDevice.json"
        let unsafe1 = "../dangerous"
        let unsafe2 = "file\0name"

        // When/Then: Validation should detect safety
        #expect(safe.isSafeFilename())
        #expect(!unsafe1.isSafeFilename())
        #expect(!unsafe2.isSafeFilename())
    }
}

// MARK: - Query Operations Tests

@Suite("CodableIndexedStore - Queries")
struct QueryOperationsTests {

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let namespace = "QueryTests"

    @Test("Contains returns true for existing item")
    func containsExistingItem() async throws {
        defer { cleanup() }

        // Given: Store with item
        let store = createStore()
        let user = TestUser(id: UUID(), name: "Test", email: "test@example.com", age: 25)
        _ = try await store.save(user)

        // When/Then: Contains should return true
        let contains = await store.contains(id: user.id)
        #expect(contains)
    }

    @Test("Contains returns false for non-existent item")
    func containsNonExistentItem() async throws {
        defer { cleanup() }

        // Given: Empty store
        let store = createStore()

        // When/Then: Contains should return false
        let contains = await store.contains(id: UUID())
        #expect(!contains)
    }

    @Test("AllIDs returns all item identifiers")
    func allIDsQuery() async throws {
        defer { cleanup() }

        // Given: Store with multiple items
        let store = createStore()
        let ids = [UUID(), UUID(), UUID()]

        for id in ids {
            let user = TestUser(id: id, name: "User", email: "user@example.com", age: 25)
            _ = try await store.save(user)
        }

        // When: Querying all IDs
        let allIDs = await store.allIDs

        // Then: Should return all IDs
        #expect(allIDs.count == 3)
        #expect(Set(allIDs) == Set(ids))
    }

    @Test("Statistics returns accurate counts and timestamps")
    func statisticsQuery() async throws {
        defer { cleanup() }

        // Given: Store with items
        let store = createStore()

        for i in 1...3 {
            let user = TestUser(id: UUID(), name: "User\(i)", email: "user\(i)@example.com", age: 20 + i)
            _ = try await store.save(user)
        }

        // When: Getting statistics
        let stats = try await store.statistics()

        // Then: Should have accurate data
        #expect(stats.totalItems == 3)
        #expect(stats.oldestCreated != nil)
        #expect(stats.newestCreated != nil)
    }

    // MARK: - Helpers

    private func createStore()  -> CodableIndexedStore<TestUser> {
        CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(autoCreateDirectory: true)
        )
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Custom Encoder/Decoder Tests

@Suite("CodableIndexedStore - Custom Encoder/Decoder")
struct CustomEncoderDecoderTests {

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let namespace = "CustomEncoderTest"

    @Test("Store works with custom ISO8601 encoder/decoder")
    func customISO8601Encoder() async throws {
        defer { cleanup() }

        // Given: Store with ISO8601 configuration
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: .iso8601
        )

        let user = TestUser(id: UUID(), name: "ISO Test", email: "iso@example.com", age: 30)

        // When: Saving item
        _ = try await store.save(user)

        // Then: Should be able to fetch back
        let fetched = try await store.fetch(id: user.id)
        #expect(fetched.id == user.id)
        #expect(fetched.name == "ISO Test")
    }

    @Test("Store works with compact configuration")
    func compactConfiguration() async throws {
        defer { cleanup() }

        // Given: Store with compact configuration
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: .compact
        )

        let user = TestUser(id: UUID(), name: "Compact", email: "compact@example.com", age: 25)

        // When: Saving item
        _ = try await store.save(user)

        // Then: Should be able to fetch back
        let fetched = try await store.fetch(id: user.id)
        #expect(fetched.id == user.id)
        #expect(fetched.name == "Compact")
    }

    @Test("Store works with debug configuration")
    func debugConfiguration() async throws {
        defer { cleanup() }

        // Given: Store with debug configuration
        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: .debug
        )

        let user = TestUser(id: UUID(), name: "Debug", email: "debug@example.com", age: 35)

        // When: Saving item
        _ = try await store.save(user)

        // Then: Should be able to fetch back
        let fetched = try await store.fetch(id: user.id)
        #expect(fetched.id == user.id)
        #expect(fetched.name == "Debug")
    }

    @Test("Store works with fully custom encoder")
    func fullyCustomEncoder() async throws {
        defer { cleanup() }

        // Given: Custom encoder with snake_case keys
        let customEncoder = JSONEncoder()
        customEncoder.keyEncodingStrategy = .convertToSnakeCase
        customEncoder.outputFormatting = [.prettyPrinted]

        let customDecoder = JSONDecoder()
        customDecoder.keyDecodingStrategy = .convertFromSnakeCase

        let store = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: CodableIndexedStore<TestUser>.Configuration(
                encoder: customEncoder,
                decoder: customDecoder
            )
        )

        let user = TestUser(id: UUID(), name: "Custom", email: "custom@example.com", age: 40)

        // When: Saving and fetching item
        _ = try await store.save(user)
        let fetched = try await store.fetch(id: user.id)

        // Then: Should work correctly
        #expect(fetched.id == user.id)
        #expect(fetched.name == "Custom")
        #expect(fetched.email == "custom@example.com")
        #expect(fetched.age == 40)
    }

    // MARK: - Helpers

    private func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Recreate on Decoding Error Tests

@Suite("CodableIndexedStore - Recreate on Decoding Error")
struct RecreateOnDecodingErrorTests {

    @Test("Store recreates when manifest decoding fails with recreateOnDecodingError=true")
    func recreateOnManifestDecodingError() async throws {
        // Given: Store with recreateOnDecodingError enabled
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let namespace = "TestUsers"

        // Create store and save an item
        let store1 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" }
        )

        let user = TestUser(id: UUID(), name: "Test", email: "test@example.com", age: 30)
        _ = try await store1.save(user)

        // Corrupt the manifest file (write invalid JSON)
        let manifestURL = tempDir.appendingPathComponent("\(namespace).json")
        try "INVALID JSON".write(to: manifestURL, atomically: true, encoding: .utf8)

        // When: Creating new store with recreateOnDecodingError=true
        let config = CodableIndexedStore<TestUser>.Configuration(
            recreateOnDecodingError: true
        )

        let store2 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: config
        )

        // Then: Store should be empty (recreated)
        let count = await store2.count
        #expect(count == 0)

        let allItems = try await store2.fetchAll()
        #expect(allItems.isEmpty)

        // And: Old item files should be deleted
        let itemsDir = tempDir.appendingPathComponent(namespace)
        let contents = try? FileManager.default.contentsOfDirectory(
            at: itemsDir,
            includingPropertiesForKeys: nil
        )
        #expect(contents?.isEmpty ?? true)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Store throws error when manifest decoding fails with recreateOnDecodingError=false")
    func throwOnManifestDecodingError() async throws {
        // Given: Store with recreateOnDecodingError disabled (default)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let namespace = "TestUsers"

        // Create store and save an item
        let store1 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" }
        )

        let user = TestUser(id: UUID(), name: "Test", email: "test@example.com", age: 30)
        _ = try await store1.save(user)

        // Corrupt the manifest file (write invalid JSON)
        let manifestURL = tempDir.appendingPathComponent("\(namespace).json")
        try "INVALID JSON".write(to: manifestURL, atomically: true, encoding: .utf8)

        // When: Creating new store with recreateOnDecodingError=false (default)
        let config = CodableIndexedStore<TestUser>.Configuration(
            recreateOnDecodingError: false
        )

        let store2 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: config
        )

        // Then: Should throw error on first operation
        await #expect(throws: IndexedStoreError.self) {
            try await store2.fetchAll()
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Recreate preserves namespace structure")
    func recreatePreservesNamespace() async throws {
        // Given: Store with recreateOnDecodingError enabled
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let namespace = "TestUsers"

        // Create store and save items
        let store1 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" }
        )

        let user1 = TestUser(id: UUID(), name: "User1", email: "user1@example.com", age: 25)
        let user2 = TestUser(id: UUID(), name: "User2", email: "user2@example.com", age: 35)
        _ = try await store1.save(user1)
        _ = try await store1.save(user2)

        // Corrupt the manifest
        let manifestURL = tempDir.appendingPathComponent("\(namespace).json")
        try "INVALID JSON".write(to: manifestURL, atomically: true, encoding: .utf8)

        // When: Creating new store with recreateOnDecodingError=true
        let config = CodableIndexedStore<TestUser>.Configuration(
            recreateOnDecodingError: true
        )

        let store2 = CodableIndexedStore<TestUser>(
            directory: tempDir,
            namespace: namespace,
            filename: { id in "\(id.uuidString).json" },
            configuration: config
        )

        // Then: Directory structure should exist
        let itemsDir = tempDir.appendingPathComponent(namespace)
        let dirExists = FileManager.default.fileExists(atPath: itemsDir.path)
        #expect(dirExists)

        // And: New items can be saved
        let newUser = TestUser(id: UUID(), name: "NewUser", email: "new@example.com", age: 40)
        _ = try await store2.save(newUser)

        let count = await store2.count
        #expect(count == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}
