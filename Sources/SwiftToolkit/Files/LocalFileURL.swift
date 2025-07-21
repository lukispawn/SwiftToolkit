//
//  LocalFileURL.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 16/05/2025.
//

import Foundation

public struct LocalFileURL: Codable, Sendable, CustomStringConvertible, Equatable {
   
    public let directory: Directory
    public let fileName: String
    
   
    public init(directory: Directory, fileName: String?) {
        self.directory = directory
        self.fileName = fileName ?? ""
    }
    
    public init(fileURL: URL) {
        self.directory = .custom(fileURL.deletingLastPathComponent().path(percentEncoded: false))
        self.fileName = fileURL.lastPathComponent
    }
    
    public init(directoryURL: URL, fileName: String?) {
        self.directory = .custom(directoryURL.path())
        self.fileName = fileName ?? ""
    }

    public func fileURL(createFolders: Bool = false) throws -> URL {
        try directory.getURL(createFolders: createFolders).appendingPathComponent(fileName, isDirectory: false)
    }
    
    public func directoryURL(createFolders: Bool = false) throws -> URL {
        try directory.getURL(createFolders: createFolders)
    }
    
    public var path: String? {
        directory.subpath
    }
    
    public func directoryExists() -> Bool {
        directory.directoryExists()
    }
    
    public func fileExists() -> Bool {
        guard let url = try? fileURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public func deleteFile() throws {
        guard let url = try? fileURL() else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    public func createFolderIfNeeded() throws{
        try directory.createFolderIfNeeded()
    }
    
    static func isDirectory(url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory == true
        } catch {
            return false
        }
    }
    
    public var description: String {
        guard let url = try? fileURL() else { return "Invalid url"}
        return url.description
    }
}

extension LocalFileURL {
    
    enum DirectoryError: Error {
        case missingCustomPath
    }
    
    public struct Directory: Codable, Sendable, Equatable {
        
        public enum Root: String, Codable, Sendable {
            case documents
            case caches
            case applicationSupport
            case temporary
            case custom
        }
        
        public let root: Root
        private let path: String?

        init(root: Root, path: String?) {
            self.root = root
            self.path = path
        }
        
        public static func documents(_ path: String? = nil)-> Self{
            return .init(root: .documents, path: path)
        }
        public static func caches(_ path: String? = nil)-> Self{
            return .init(root: .caches, path: path)
        }
        public static func applicationSupportDirectory(_ path: String? = nil)-> Self{
            return .init(root: .applicationSupport, path: path)
        }
        public static func temporaryDirectory(_ path: String? = nil)-> Self{
            return .init(root: .temporary, path: path)
        }
        
        public static func custom(_ path: String)-> Self{
            return .init(root: .custom, path: path)
        }
        
        var customRootPath : String? {
            switch root {
            case .custom:
                return path
            default:
                return nil
            }
        }
        var subpath: String?{
            switch root {
            case .custom:
                return nil
            default:
                return path
            }
        }
        
    }
    
   
}

extension LocalFileURL.Directory {
    
    public func directoryExists() -> Bool {
        guard let url = try? getURL(createFolders: false) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public func getURL(createFolders: Bool = false) throws -> URL {
        let fileManager = FileManager.default
        
        var baseURL: URL

        switch self.root {
        case .documents:
            let searchPathDirectory:FileManager.SearchPathDirectory = .documentDirectory
            baseURL = try fileManager.url(
                for: searchPathDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .caches:
            let searchPathDirectory: FileManager.SearchPathDirectory = .cachesDirectory
            baseURL = try fileManager.url(
                for: searchPathDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .applicationSupport:
            let searchPathDirectory: FileManager.SearchPathDirectory = .applicationSupportDirectory
            baseURL = try fileManager.url(
                for: searchPathDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .temporary:
            baseURL = FileManager.default.temporaryDirectory
        case .custom:
            if let path = customRootPath{
                baseURL = URL(fileURLWithPath: path)
            }else{
                fatalError("missing custom root path")
                //throw LocalFileURL.DirectoryError.missingCustomPath
            }
            
        }
        
        if let subpath = subpath , !subpath.isEmpty {
            baseURL.appendPathComponent(subpath, isDirectory: true)
        }

        // Create intermediate directories if they do not exist
        if !fileManager.fileExists(atPath: baseURL.path) && createFolders{
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        }

        return baseURL
    }
    
    public func createFolderIfNeeded() throws {
        let fileManager = FileManager.default
        let baseURL = try self.getURL(createFolders: false)
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
}


