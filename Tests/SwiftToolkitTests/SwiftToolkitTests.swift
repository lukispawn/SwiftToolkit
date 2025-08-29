import Testing
import Foundation
@testable import SwiftToolkit

@Suite("SwiftToolkit Core Tests")
struct SwiftToolkitTests {
    
    @Test("Package information is correct")
    func packageInfo() {
        #expect(SwiftToolkit.name == "SwiftToolkit")
        #expect(SwiftToolkit.version == "1.3.4")
    }
    
    @Test("AsyncLock ensures sequential access")
    func asyncLock() async throws {
        let lock = AsyncLock<String, Error>()
        let executionCount = Counter()
        
        // Test that the lock ensures only one task executes (others get same result)
        let results = await withTaskGroup(of: String.self) { group in
            for i in 0..<3 {
                group.addTask {
                    return try! await lock.perform {
                        // Small delay to ensure race condition would occur without lock
                        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        await executionCount.increment()
                        return "executed-once"
                    }
                }
            }
            
            var results: [String] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        let count = await executionCount.value
        #expect(count == 1, "AsyncLock should execute operation only once")
        #expect(results.count == 3, "All callers should get a result")
        #expect(results.allSatisfy { $0 == "executed-once" }, "All results should be the same")
    }
    
    @Test("StorageCodable saves and loads data correctly")
    func storageCodable() async throws {
        struct TestData: Codable, Equatable {
            let value: String
            let number: Int
        }
        
        let testData = TestData(value: "test", number: 42)
        let file = LocalFileURL(
            directory: .temporaryDirectory(),
            fileName: "test-\(UUID().uuidString).json"
        )
        
        // Test save and load
        try StorageCodable.store(testData, to: file)
        let loadedData = try StorageCodable.retrieve(file, as: TestData.self)
        
        #expect(loadedData != nil)
        #expect(testData == loadedData!)
        
        // Clean up
        let fileURL = try file.fileURL()
        try FileManager.default.removeItem(at: fileURL)
    }
    
    @Test("AsyncCancelBag cancels tasks properly")
    func asyncCancelBag() async throws {
        let cancelBag = AsyncCancelBag()
        var taskCompleted = false
        
        let task = Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            taskCompleted = true
        }
        await cancelBag.insert(task.eraseToAnyCancellable())
        
        // Cancel immediately
        await cancelBag.cancel()
        
        // Give a moment for cancellation to take effect
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        #expect(!taskCompleted, "Task should have been cancelled")
    }
}

// Temporarily commented out for performance testing
/*
@Suite("Async Utilities Tests")
struct AsyncUtilitiesTests {
    
    @Test("AsyncThrottler throttles operations correctly")
    func asyncThrottler() async throws {
        let throttler = tocheck__AsyncThrottler<String, Void>()
        let callCounter = Counter()
        
        // Make 3 rapid calls - should only execute one due to throttling  
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    _ = try? await throttler.schedule(forKey: "test", throttleInterval: 0.1) {
                        await callCounter.increment()
                    }
                }
            }
        }
        
        let callCount = await callCounter.value
        #expect(callCount == 1, "Only one call should execute due to throttling")
    }
    
    @Test("DebounceAsync debounces operations correctly")
    func debounceAsync() async throws {
        let callCounter = Counter()
        let debouncer = DebounceAsync()
        
        // Make multiple rapid calls
        await debouncer.schedule(after: 0.05) {
            await callCounter.increment()
        }
        await debouncer.schedule(after: 0.05) {
            await callCounter.increment()
        }
        await debouncer.schedule(after: 0.05) {
            await callCounter.increment()
        }
        
        // Wait for debounce interval
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms
        
        let callCount = await callCounter.value
        #expect(callCount == 1, "Only one call should execute due to debouncing")
    }
}
*/