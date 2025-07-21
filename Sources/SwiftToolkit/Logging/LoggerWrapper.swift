//
//  LoggerWrapper.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 23/05/2025.
//

import Foundation
import os

public struct LoggerWrapper: Sendable {
    let logger: Logger
    let prefix: String?
    let minLevel: Level
    let enabled: Bool

    public func osLogger()-> Logger {
        return logger
    }
    
    public init(
        logger: Logger,
        prefix: String?,
        minLevel: Level = .default,
        enabled: Bool = true
    ) {
        self.logger = logger
        self.prefix = prefix
        self.minLevel = minLevel
        self.enabled = enabled
    }

    public enum Level: Int, Sendable {
        case `default` = 0
        case debug = 2
        case info = 3
        case warning = 5
        case error = 6

        var string: String {
            switch self {
            case .default:
                return "VERBOSE"
            case .debug:
                return "DEBUG"
            case .info:
                return "INFO"
            case .warning:
                return "WARNING"
            case .error:
                return "ERROR"
            }
        }

        var osLevel: OSLogType {
            switch self {
            case .default:
                return .default
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .error
            case .error:
                return .fault
            }
        }
    }

    func log(customLevel level: Level = .default, _ message: String) {
        guard shouldLevelBeLogged(level) else { return }
        log(level: level.osLevel, message)
    }

    private func shouldLevelBeLogged(_ level: Level, message: String? = nil) -> Bool {
        if level.rawValue >= minLevel.rawValue {
            return true
        }
        return false
    }

    public func log(level: OSLogType = .default, _ message: String) {
        guard enabled else { return }
        if let prefix {
            logger.log(level: level, "\(prefix) \(message)")
        } else {
            logger.log(level: level, "\(message)")
        }
    }

    public func verbose(_ message: String) {
        self.log(customLevel: .default, message)
    }

    public func debug(_ message: String) {
        self.log(customLevel: .debug, message)
    }

    public func info(_ message: String) {
        self.log(customLevel: .info, message)
    }

    public func warning(_ message: String) {
        self.log(customLevel: .warning, message)
    }

    public func error(_ message: String) {
        self.log(customLevel: .error, message)
    }
}

