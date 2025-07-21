//
//  Untitled.swift
//  LoadableModel
//
//  Created by Lukasz Zajdel on 04/06/2025.
//
import Foundation
import Combine

public actor AsyncCancelBag: @preconcurrency CustomStringConvertible {
    
    struct TaskBox: @unchecked Sendable, Hashable, Equatable {
        let id: UUID = .init()
        let value: AnyCancellable
        let customId: String?
        
        init(_ value: AnyCancellable, customId: String? = nil) {
            self.value = value
            self.customId = customId
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: TaskBox, rhs: TaskBox) -> Bool {
            lhs.id == rhs.id
        }
    }

    private var subscriptions = Set<TaskBox>()

    public init() {}

    deinit {
        cancelSync()
    }
    
    public var description: String {
        return "<AsyncCancelBag:\(subscriptions.count)>"
    }

    func insert(box: TaskBox) {
        subscriptions.insert(box)
    }

    @discardableResult
    public func insert(_ cancellable: AnyCancellable, customId: String? = nil) -> UUID {
        let box = TaskBox(cancellable, customId: customId)
        self.insert(box: box)
        return box.id
    }

    
    public func cancel(withTaskId id: UUID) {
        for box in subscriptions where box.id == id {
            box.value.cancel()
            subscriptions.remove(box)
        }
    }
    
    public func cancel(withUserId id: String) {
        for box in subscriptions where box.customId == id {
            box.value.cancel()
            subscriptions.remove(box)
        }
    }
    
    public func cancel() {
        subscriptions.forEach { $0.value.cancel() }
        subscriptions.removeAll()
    }
    
    nonisolated public func cancelSync() {
        Task { [weak self] in
            await self?.cancel()
        }
    }

}

public extension AnyCancellable {
    @discardableResult
    func store(in cancelBag: AsyncCancelBag, customId: String? = nil) async -> UUID{
        let box = AsyncCancelBag.TaskBox(self, customId: customId)
        await cancelBag.insert(box: box)
        return box.id
    }
}

public extension Task {
    @discardableResult
    func store(in cancelBag: AsyncCancelBag, customId: String? = nil) async -> UUID{
        let box = AsyncCancelBag.TaskBox(self.eraseToAnyCancellable(), customId: customId)
        await cancelBag.insert(box: box)
        return box.id
    }
}

public extension Task {
  func eraseToAnyCancellable() -> AnyCancellable {
        AnyCancellable(cancel)
    }
}

