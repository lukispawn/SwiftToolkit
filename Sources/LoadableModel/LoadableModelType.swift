//
//  File.swift
//  
//
//  Created by Lukasz Zajdel on 21/12/2023.
//

import Foundation

public protocol LoadableModelSupport {
    @MainActor
    var loadState: LoadableState { get }
    func onTask() async
    func refresh(setting: RefreshSettings) async throws
}

public enum RefreshDisposition<Model>: @unchecked Sendable {
    case provide(Result<Model, Error>)
    case proceed
}

public protocol LoadSettings: Sendable {
    var reason: String { get }
    var resetLast: Bool { get }
}

public struct RefreshSettings: LoadSettings, Sendable {
    public let reason: String
    public let debounce: Bool
    public let resetLast: Bool

    public init(
        reason: String = "Generic",
        debounce: Bool = false,
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.debounce = debounce
        self.resetLast = resetLast
    }
}

public struct ReloadSettings: LoadSettings, Sendable {
    public let reason: String
    public let resetLast: Bool

    public init(
        reason: String = "Generic",
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.resetLast = resetLast
    }
}

public enum RefreshTrigger: String, CaseIterable, Sendable, Hashable {
    case timer
    case reachability
    case appForeground
    case significantTimeChange
    case refreshOnTask
}
