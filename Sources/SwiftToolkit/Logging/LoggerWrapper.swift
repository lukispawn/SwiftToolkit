//
//  LoggerWrapper.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 23/05/2025.
//

import Foundation
import os

public struct LoggerWrapper: Sendable {
    @usableFromInline
    let logger: Logger
    @usableFromInline
    let prefix: String?
    @usableFromInline
    let minLevel: Level
    @usableFromInline
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

        @usableFromInline
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

    @_transparent
    @usableFromInline
    func log(customLevel level: Level = .default, _ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        guard shouldLevelBeLogged(level) else { return }
        log(level: level.osLevel, message, fileID: fileID, function: function, line: line)
    }

    @usableFromInline
    func shouldLevelBeLogged(_ level: Level, message: String? = nil) -> Bool {
        if level.rawValue >= minLevel.rawValue {
            return true
        }
        return false
    }

    @_transparent
    public func log(level: OSLogType = .default, _ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        guard enabled else { return }

        // Create location context for better debugging
        let fileName = (String(describing: fileID) as NSString).lastPathComponent
        let location = "\(fileName):\(line)"

        if let prefix {
            // Include source location in structured format for OSLog
            logger.log(level: level, "\(prefix) \(message) [\(location)]")
        } else {
            logger.log(level: level, "\(message) [\(location)]")
        }
    }

    @_transparent
    public func verbose(_ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        self.log(customLevel: .default, message, fileID: fileID, function: function, line: line)
    }

    @_transparent
    public func debug(_ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        self.log(customLevel: .debug, message, fileID: fileID, function: function, line: line)
    }

    @_transparent
    public func info(_ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        self.log(customLevel: .info, message, fileID: fileID, function: function, line: line)
    }

    @_transparent
    public func warning(_ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        self.log(customLevel: .warning, message, fileID: fileID, function: function, line: line)
    }

    @_transparent
    public func error(_ message: String, fileID: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        self.log(customLevel: .error, message, fileID: fileID, function: function, line: line)
    }
}

