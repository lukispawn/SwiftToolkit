//
//  CombineCancelBag.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import Combine
import Foundation

public final class CombineCancelBag: CustomStringConvertible, Cancellable, @unchecked Sendable {
    public var description: String {
        return "<CombineCancelBag:\(subscriptions.count)>"
    }

    var subscriptions = Set<AnyCancellable>()

    public init() {}

    public func insert(_ cancellable: AnyCancellable) {
        subscriptions.insert(cancellable)
    }
    
    public func cancel() {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    public func clear() {
        subscriptions.removeAll()
    }
}

public extension Task {
    func store(in cancelBag: CombineCancelBag)  {
        cancelBag.insert(self.eraseToAnyCancellable())
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CombineCancelBag) {
        cancelBag.subscriptions.insert(self)
    }
}


