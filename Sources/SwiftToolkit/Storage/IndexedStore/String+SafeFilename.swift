//
//  SafeFilenameHelpers.swift
//  SwiftToolkit
//
//  Security helpers for safe filename generation
//

import Foundation

// MARK: - String Extensions

extension String {

    /// Convert string to safe filename by removing/replacing dangerous characters
    ///
    /// **Security Features**:
    /// - Removes path traversal sequences (`../`, `..\\`)
    /// - Removes null bytes (`\0`)
    /// - Replaces forbidden characters with underscores
    /// - Handles Windows reserved names (`CON`, `PRN`, `NUL`, etc.)
    /// - Enforces maximum length (255 characters)
    /// - Trims whitespace and dots
    ///
    /// **Platform-Specific**:
    /// - macOS: Forbids `:` and `/`
    /// - Windows: Forbids `<>:"|?*\\/`
    /// - Unix: Forbids `/` and null byte
    ///
    /// **Returns**: Safe filename or empty string if input was entirely unsafe
    ///
    /// **Example**:
    /// ```swift
    /// "My Device/Name".makeSafeFilename()  // "My Device_Name"
    /// "../../../etc/passwd".makeSafeFilename()  // "etc_passwd"
    /// "CON".makeSafeFilename()  // "CON_" (Windows reserved)
    /// ```
    func makeSafeFilename() -> String {
        var safe = self

        // 1. Remove null bytes (security: null byte injection)
        safe = safe.replacingOccurrences(of: "\0", with: "")

        // 2. Remove path traversal sequences (security: directory traversal)
        safe = safe.replacingOccurrences(of: "../", with: "")
        safe = safe.replacingOccurrences(of: "..\\", with: "")

        // 3. Replace forbidden characters (platform-specific)
        let forbiddenChars: CharacterSet
        #if os(Windows)
        // Windows: < > : " | ? * \ /
        forbiddenChars = CharacterSet(charactersIn: "<>:\"|?*\\/")
        #else
        // macOS/Unix: : / (macOS Finder shows : as /)
        forbiddenChars = CharacterSet(charactersIn: ":/")
        #endif

        safe = safe.components(separatedBy: forbiddenChars).joined(separator: "_")

        // 4. Trim leading/trailing whitespace and dots
        safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        safe = safe.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        // 5. Handle Windows reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
        #if os(Windows)
        let reservedNames = [
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        ]
        let nameWithoutExtension = (safe as NSString).deletingPathExtension
        if reservedNames.contains(nameWithoutExtension.uppercased()) {
            safe = "\(safe)_"
        }
        #endif

        // 6. Enforce maximum filename length (255 bytes on most filesystems)
        if safe.utf8.count > 255 {
            // Truncate to 255 bytes while preserving UTF-8 validity
            let prefix = String(safe.utf8.prefix(251))!  // Leave room for .json
            safe = prefix
        }

        return safe
    }

    /// Validate if string is a safe filename
    ///
    /// **Checks**:
    /// - Not empty
    /// - No path traversal sequences
    /// - No null bytes
    /// - No forbidden characters
    /// - Not Windows reserved name
    /// - Within length limits
    ///
    /// **Returns**: `true` if string is safe as-is
    ///
    /// **Example**:
    /// ```swift
    /// "MyDevice".isSafeFilename()  // true
    /// "../etc/passwd".isSafeFilename()  // false
    /// "CON".isSafeFilename()  // false (Windows)
    /// ```
    func isSafeFilename() -> Bool {
        guard !isEmpty else { return false }

        // Check if sanitized version equals original
        return makeSafeFilename() == self
    }
}

// MARK: - Validation Helpers

extension String {

    /// Check if string contains path traversal sequences
    var containsPathTraversal: Bool {
        contains("../") || contains("..\\")
    }

    /// Check if string contains null bytes
    var containsNullByte: Bool {
        contains("\0")
    }

    /// Check if string is Windows reserved name
    var isWindowsReservedName: Bool {
        #if os(Windows)
        let reservedNames = [
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        ]
        let nameWithoutExtension = (self as NSString).deletingPathExtension
        return reservedNames.contains(nameWithoutExtension.uppercased())
        #else
        return false
        #endif
    }
}
