//
//  StorageCodable.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 16/05/2025.
//

import Foundation

public class StorageCodable {
    fileprivate init() {}

    /// Store an encodable struct to the specified directory on disk
    ///
    /// - Parameters:
    ///   - object: the encodable struct to store
    ///   - directory: where to store the struct
    ///   - fileName: what to name the file where the struct data will be stored
    public static func store<T: Encodable>(_ object: T, to file: LocalFileURL) throws {
        
        let url = try file.fileURL(createFolders: true)

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            try data.write(to: url, options: [.atomicWrite])
//
        } catch {
            throw error
        }
    }

    /// Retrieve and convert a struct from a file on disk
    ///
    /// - Parameters:
    ///   - fileName: name of the file where struct data is stored
    ///   - directory: directory where struct data is stored
    ///   - type: struct type (i.e. Message.self)
    /// - Returns: decoded struct model(s) of data
    public static func retrieve<T: Decodable>(_ file: LocalFileURL, as type: T.Type) throws -> T? {
        let url = try file.fileURL()

        if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }

        if let data = FileManager.default.contents(atPath: url.path) {
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(type, from: data)
                return model
            } catch {
                throw error
            }
        } else {
            return nil
        }
    }

    /// Remove all files at specified directory
    public static func clear(_ directory: LocalFileURL.Directory) {
        guard let url = try? directory.getURL() else { return }
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            for fileUrl in contents {
                try FileManager.default.removeItem(at: fileUrl)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// Remove specified file from specified directory
    public static func remove(_ file: LocalFileURL) {
        guard let url = try? file.fileURL() else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    /// Returns BOOL indicating whether file exists at specified directory with specified file name
    public static func fileExists(_ file: LocalFileURL) -> Bool {
        file.fileExists()
    }
}
