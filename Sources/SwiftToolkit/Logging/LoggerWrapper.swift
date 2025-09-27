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

    func log(customLevel level: Level = .default, _ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        guard shouldLevelBeLogged(level) else { return }
        log(level: level.osLevel, message, file: file, function: function, line: line)
    }

    private func shouldLevelBeLogged(_ level: Level, message: String? = nil) -> Bool {
        if level.rawValue >= minLevel.rawValue {
            return true
        }
        return false
    }

    public func log(level: OSLogType = .default, _ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        guard enabled else { return }

        // Create location context for better debugging
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line)"

        if let prefix {
            // Include source location in structured format for OSLog
            logger.log(level: level, "\(prefix) \(message) [\(location)]")
        } else {
            logger.log(level: level, "\(message) [\(location)]")
        }
    }

    public func verbose(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(customLevel: .default, message, file: file, function: function, line: line)
    }

    public func debug(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(customLevel: .debug, message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(customLevel: .info, message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(customLevel: .warning, message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(customLevel: .error, message, file: file, function: function, line: line)
    }
}

