import Testing
@testable import SwiftToolkit

@Suite("SwiftToolkit Core Tests")
struct SwiftToolkitTests {
    
    @Test("Package information is correct")
    func packageInfo() {
        #expect(SwiftToolkit.name == "SwiftToolkit")
        #expect(SwiftToolkit.version == "0.1.0")
    }
    
    @Test("AsyncLock ensures sequential access")
    func asyncLock() async throws {
        let lock = AsyncLock()
        var counter = 0
        
        // Test that the lock works sequentially
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await lock.withLock {
                        let currentValue = counter
                        // Small delay to ensure race condition would occur without lock
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        counter = currentValue + 1
                    }
                }
            }
        }
        
        #expect(counter == 5)
    }
    
    @Test("StorageCodable saves and loads data correctly")
    func storageCodable() async throws {
        struct TestData: Codable, Equatable {
            let value: String
            let number: Int
        }
        
        let testData = TestData(value: "test", number: 42)
        let storage = StorageCodable<TestData>(
            filename: "test-\(UUID().uuidString).json",
            directory: .temporaryDirectory
        )
        
        // Test save and load
        try await storage.save(testData)
        let loadedData = try await storage.load()
        
        #expect(testData == loadedData)
        
        // Clean up
        try await storage.delete()
    }
    
    @Test("AsyncCancelBag cancels tasks properly")
    func asyncCancelBag() async throws {
        let cancelBag = AsyncCancelBag()
        var taskCompleted = false
        
        await cancelBag.addTask {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            taskCompleted = true
        }
        
        // Cancel immediately
        await cancelBag.cancelAll()
        
        // Give a moment for cancellation to take effect
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        #expect(!taskCompleted, "Task should have been cancelled")
    }
}

@Suite("Async Utilities Tests")
struct AsyncUtilitiesTests {
    
    @Test("AsyncThrottler throttles operations correctly")
    func asyncThrottler() async throws {
        let throttler = AsyncThrottler()
        var callCount = 0
        
        // Make 3 rapid calls - should only execute one due to throttling
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    await throttler.throttle(key: "test", interval: 0.1) {
                        callCount += 1
                    }
                }
            }
        }
        
        #expect(callCount == 1, "Only one call should execute due to throttling")
    }
    
    @Test("DebounceAsync debounces operations correctly")
    func debounceAsync() async throws {
        var callCount = 0
        let debounced = DebounceAsync(interval: 0.05) {
            callCount += 1
        }
        
        // Make multiple rapid calls
        debounced()
        debounced()
        debounced()
        
        // Wait for debounce interval
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms
        
        #expect(callCount == 1, "Only one call should execute due to debouncing")
    }
}