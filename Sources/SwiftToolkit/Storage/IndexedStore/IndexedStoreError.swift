//
//  IndexedStoreError.swift
//  SwiftToolkit
//
//  Error types for CodableIndexedStore operations
//

import Foundation

/// Errors thrown by CodableIndexedStore operations
public enum IndexedStoreError: Error, Sendable {

    // MARK: - File System Errors

    /// Failed to create store directory
    case directoryCreationFailed(path: String, underlying: Error)

    /// Failed to create namespace folder
    case namespaceFolderCreationFailed(namespace: String, underlying: Error)

    /// Store directory does not exist
    case directoryNotFound(path: String)

    /// Failed to access file system
    case fileSystemAccessFailed(path: String, underlying: Error)

    // MARK: - Index Errors

    /// Failed to load index file
    case indexLoadFailed(path: String, underlying: Error)

    /// Failed to save index file
    case indexSaveFailed(path: String, underlying: Error)

    /// Index is corrupted or invalid
    case indexCorrupted(path: String, reason: String)

    /// Index namespace mismatch
    case namespaceMismatch(expected: String, found: String)

    // MARK: - Item Errors

    /// Item not found in store
    case itemNotFound(id: String)

    /// Failed to load item file
    case itemLoadFailed(id: String, filename: String, underlying: Error)

    /// Failed to save item file
    case itemSaveFailed(id: String, filename: String, underlying: Error)

    /// Failed to delete item file
    case itemDeleteFailed(id: String, filename: String, underlying: Error)

    /// Item file is corrupted
    case itemCorrupted(id: String, filename: String, underlying: Error)

    // MARK: - Encoding/Decoding Errors

    /// Failed to encode item to JSON
    case encodingFailed(id: String, underlying: Error)

    /// Failed to decode item from JSON
    case decodingFailed(id: String, underlying: Error)

    /// Failed to encode index to JSON
    case indexEncodingFailed(underlying: Error)

    /// Failed to decode index from JSON
    case indexDecodingFailed(underlying: Error)

    // MARK: - Validation Errors

    /// Filename is unsafe (contains path traversal, etc.)
    case unsafeFilename(id: String, filename: String, reason: String)

    /// Namespace contains unsafe characters
    case unsafeNamespace(namespace: String, reason: String)

    /// Empty namespace not allowed
    case emptyNamespace

    // MARK: - Concurrency Errors

    /// Operation cancelled
    case operationCancelled

    /// Store is not initialized
    case notInitialized

    /// Store is already initialized
    case alreadyInitialized
}

// MARK: - Error Descriptions

extension IndexedStoreError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        // File System
        case .directoryCreationFailed(let path, _):
            return "Failed to create store directory at '\(path)'"
        case .namespaceFolderCreationFailed(let namespace, _):
            return "Failed to create namespace folder '\(namespace)'"
        case .directoryNotFound(let path):
            return "Store directory not found at '\(path)'"
        case .fileSystemAccessFailed(let path, _):
            return "Failed to access file system at '\(path)'"

        // Index
        case .indexLoadFailed(let path, _):
            return "Failed to load index from '\(path)'"
        case .indexSaveFailed(let path, _):
            return "Failed to save index to '\(path)'"
        case .indexCorrupted(let path, let reason):
            return "Index corrupted at '\(path)': \(reason)"
        case .namespaceMismatch(let expected, let found):
            return "Namespace mismatch: expected '\(expected)', found '\(found)'"

        // Items
        case .itemNotFound(let id):
            return "Item not found: \(id)"
        case .itemLoadFailed(let id, let filename, _):
            return "Failed to load item '\(id)' from '\(filename)'"
        case .itemSaveFailed(let id, let filename, _):
            return "Failed to save item '\(id)' to '\(filename)'"
        case .itemDeleteFailed(let id, let filename, _):
            return "Failed to delete item '\(id)' at '\(filename)'"
        case .itemCorrupted(let id, let filename, _):
            return "Item '\(id)' corrupted at '\(filename)'"

        // Encoding/Decoding
        case .encodingFailed(let id, _):
            return "Failed to encode item '\(id)' to JSON"
        case .decodingFailed(let id, _):
            return "Failed to decode item '\(id)' from JSON"
        case .indexEncodingFailed:
            return "Failed to encode index to JSON"
        case .indexDecodingFailed:
            return "Failed to decode index from JSON"

        // Validation
        case .unsafeFilename(let id, let filename, let reason):
            return "Unsafe filename for item '\(id)': '\(filename)' (\(reason))"
        case .unsafeNamespace(let namespace, let reason):
            return "Unsafe namespace '\(namespace)': \(reason)"
        case .emptyNamespace:
            return "Namespace cannot be empty"

        // Concurrency
        case .operationCancelled:
            return "Operation was cancelled"
        case .notInitialized:
            return "Store is not initialized"
        case .alreadyInitialized:
            return "Store is already initialized"
        }
    }

    public var failureReason: String? {
        switch self {
        case .directoryCreationFailed(_, let error),
             .namespaceFolderCreationFailed(_, let error),
             .fileSystemAccessFailed(_, let error),
             .indexLoadFailed(_, let error),
             .indexSaveFailed(_, let error),
             .itemLoadFailed(_, _, let error),
             .itemSaveFailed(_, _, let error),
             .itemDeleteFailed(_, _, let error),
             .itemCorrupted(_, _, let error),
             .encodingFailed(_, let error),
             .decodingFailed(_, let error),
             .indexEncodingFailed(let error),
             .indexDecodingFailed(let error):
            return error.localizedDescription
        default:
            return nil
        }
    }
}

// MARK: - Convenience Helpers

extension IndexedStoreError {

    /// Check if error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .operationCancelled, .notInitialized:
            return true
        case .itemNotFound:
            return true  // Can retry or create new
        default:
            return false
        }
    }

    /// Check if error is related to file system
    public var isFileSystemError: Bool {
        switch self {
        case .directoryCreationFailed, .namespaceFolderCreationFailed,
             .directoryNotFound, .fileSystemAccessFailed:
            return true
        default:
            return false
        }
    }

    /// Check if error is related to data corruption
    public var isDataCorruption: Bool {
        switch self {
        case .indexCorrupted, .itemCorrupted:
            return true
        default:
            return false
        }
    }

    /// Check if error is related to validation
    public var isValidationError: Bool {
        switch self {
        case .unsafeFilename, .unsafeNamespace, .emptyNamespace, .namespaceMismatch:
            return true
        default:
            return false
        }
    }
}
