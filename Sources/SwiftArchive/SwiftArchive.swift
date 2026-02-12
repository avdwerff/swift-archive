//
//  SwiftArchive.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 28/12/2025.
//

import Foundation

/// SwiftArchive - Modern Swift wrapper for libarchive
///
/// A type-safe interface for reading and writing archives
/// in multiple formats including ZIP, TAR, 7z, RAR, and more.
///
/// ## Reading Archives
///
/// ```swift
/// // List entries
/// let entries = try Archive.list(url: archiveURL)
/// for entry in entries {
///     print("\(entry.path) - \(entry.size) bytes")
/// }
///
/// // Extract all
/// try Archive.extract(url: archiveURL, to: destinationURL)
///
/// // Extract single file
/// if let data = try Archive.extractFile(from: archiveURL, path: "README.md") {
///     print(String(data: data, encoding: .utf8)!)
/// }
///
/// // Get archive info
/// let info = try Archive.info(url: archiveURL)
/// print("Format: \(info.format), Entries: \(info.entryCount)")
/// ```
///
/// ## Writing Archives
///
/// ```swift
/// // Create from directory
/// try Archive.create(from: sourceDir, to: archiveURL)
///
/// // Create from files
/// try Archive.create(files: [file1, file2], to: archiveURL)
///
/// // With progress and cancellation
/// try Archive.create(files: files, to: archiveURL) { file, progress in
///     try Task.checkCancellation()
///     print("\(file.lastPathComponent): \(Int(progress * 100))%")
/// }
///
/// // Different formats
/// try Archive.create(from: sourceDir, to: tarURL, format: .tar, compression: .gzip)
/// ```
///
/// ## Format Detection
///
/// ```swift
/// let (format, compression) = try Archive.detectFormat(url: archiveURL)
/// print("Format: \(format), Compression: \(compression)")
///
/// if Archive.isArchive(url: someURL) {
///     // Handle archive
/// }
/// ```
///
public protocol ArchiveProviding: Sendable {
    func info(url: URL, password: String?) throws -> ArchiveInfo
    func list(url: URL, password: String?) throws -> [ArchiveEntry]
    func extract(url: URL, to destination: URL, password: String?, overwrite: Bool, progress: ((Double) -> Void)?) throws
    func extractFile(from url: URL, path: String, password: String?) throws -> Data?
    func create(
        from directoryURL: URL,
        to archiveURL: URL,
        format: ArchiveFormat,
        compression: ArchiveCompression?,
        compressionLevel: Int?,
        encryption: ArchiveEncryption?,
        password: String?,
        progress: ((URL, Double) throws -> Void)?
    ) throws
    func create(
        files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat,
        compression: ArchiveCompression?,
        compressionLevel: Int?,
        encryption: ArchiveEncryption?,
        password: String?,
        progress: ((URL, Double) throws -> Void)?
    ) throws
    func createEncrypted(
        files: [URL],
        to archiveURL: URL,
        password: String,
        format: ArchiveFormat,
        progress: ((URL, Double) throws -> Void)?
    ) throws
    func createEncrypted(
        from directoryURL: URL,
        to archiveURL: URL,
        password: String,
        format: ArchiveFormat,
        progress: ((URL, Double) throws -> Void)?
    ) throws
    func detectFormat(url: URL) throws -> (ArchiveFormat, ArchiveCompression)
    func isArchive(url: URL) -> Bool
}

extension ArchiveProviding {
    func create(
        from directoryURL: URL,
        to archiveURL: URL,
    ) throws {
        try create(
            from: directoryURL,
            to: archiveURL,
            format: .zip,
            compression: nil,
            compressionLevel: nil,
            encryption: nil,
            password: nil,
            progress: nil
        )
    }
}

// MARK: - Default Implementation

public struct ArchiveProvider: ArchiveProviding {
    
    public init() {}
    
    public func info(url: URL, password: String? = nil) throws -> ArchiveInfo {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.info()
    }
    
    public func list(url: URL, password: String? = nil) throws -> [ArchiveEntry] {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.listEntries()
    }
    
    public func extract(
        url: URL,
        to destination: URL,
        password: String? = nil,
        overwrite: Bool = false,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let reader = try ArchiveReader(url: url, password: password)
        try reader.extractAll(to: destination, overwrite: overwrite, progress: progress)
    }
    
    public func extractFile(from url: URL, path: String, password: String? = nil) throws -> Data? {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.extract(path: path)
    }
    
    public func create(
        from directoryURL: URL,
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        compressionLevel: Int? = nil,
        encryption: ArchiveEncryption? = nil,
        password: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        try validateOptions(
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password
        )
        let writer = ArchiveWriter(
            url: archiveURL,
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password
        )
        try writer.addDirectory(at: directoryURL, progress: progress)
    }
    
    public func create(
        files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        compressionLevel: Int? = nil,
        encryption: ArchiveEncryption? = nil,
        password: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        
        try validateOptions(
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password
        )
        
        let writer = ArchiveWriter(
            url: archiveURL,
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password
        )
        
        let totalSize = files.reduce(into: Int64(0)) { result, url in
            result += (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }
        
        var processedSize: Int64 = 0
        
        try writer.write { context in
            for file in files {
                try context.addFile(at: file)
                
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
                processedSize += fileSize
                
                try progress?(file, Double(processedSize) / Double(max(totalSize, 1)))
            }
        }
        
        try progress?(archiveURL, 1.0)
    }
    
    public func createEncrypted(
        files: [URL],
        to archiveURL: URL,
        password: String,
        format: ArchiveFormat = .zip,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        guard let encryption = format.recommendedEncryption else {
            throw ArchiveError.encryptionNotSupported(format)
        }
        
        try create(
            files: files,
            to: archiveURL,
            format: format,
            encryption: encryption,
            password: password,
            progress: progress
        )
    }
    
    public func createEncrypted(
        from directoryURL: URL,
        to archiveURL: URL,
        password: String,
        format: ArchiveFormat = .zip,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        guard let encryption = format.recommendedEncryption else {
            throw ArchiveError.encryptionNotSupported(format)
        }
        
        try create(
            from: directoryURL,
            to: archiveURL,
            format: format,
            encryption: encryption,
            password: password,
            progress: progress
        )
    }
    
    public func detectFormat(url: URL) throws -> (ArchiveFormat, ArchiveCompression) {
        let info = try info(url: url)
        return (info.format, info.compression)
    }
    
    public func isArchive(url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return (try? info(url: url)) != nil
    }
    
    // MARK: - Validation
    
    private func validateOptions(
        format: ArchiveFormat,
        compression: ArchiveCompression?,
        compressionLevel: Int?,
        encryption: ArchiveEncryption?,
        password: String?
    ) throws {

        if let compression, !compression.isAvailable {
            throw ArchiveError.compressionNotAvailable(compression)
        }
        
        if let level = compressionLevel {
            guard (1...9).contains(level) else {
                throw ArchiveError.invalidCompressionLevel(level)
            }
        }
        
        if let encryption {
            guard format.writableEncryption.contains(encryption) else {
                throw ArchiveError.encryptionNotSupported(format)
            }
            guard let password, !password.isEmpty else {
                throw ArchiveError.passwordRequired
            }
        }
        
        if let password, !password.isEmpty, encryption == nil {
            throw ArchiveError.encryptionRequired
        }
    }
    
    private func validateEncryption(
        format: ArchiveFormat,
        encryption: ArchiveEncryption?,
        password: String?
    ) throws {
        if let encryption {
            guard format.writableEncryption.contains(encryption) else {
                throw ArchiveError.encryptionNotSupported(format)
            }
            guard let password, !password.isEmpty else {
                throw ArchiveError.passwordRequired
            }
        }
        
        if let password, !password.isEmpty, encryption == nil {
            throw ArchiveError.encryptionRequired
        }
    }
}

// MARK: - Static Convenience API

public enum Archive {
    
    public static let shared: ArchiveProviding = ArchiveProvider()
    
    // MARK: - Reading
    
    public static func info(url: URL, password: String? = nil) throws -> ArchiveInfo {
        try shared.info(url: url, password: password)
    }
    
    public static func list(url: URL, password: String? = nil) throws -> [ArchiveEntry] {
        try shared.list(url: url, password: password)
    }
    
    public static func extract(
        url: URL,
        to destination: URL,
        password: String? = nil,
        overwrite: Bool = false,
        progress: ((Double) -> Void)? = nil
    ) throws {
        try shared.extract(url: url, to: destination, password: password, overwrite: overwrite, progress: progress)
    }
    
    public static func extractFile(from url: URL, path: String, password: String? = nil) throws -> Data? {
        try shared.extractFile(from: url, path: path, password: password)
    }
    
    // MARK: - Writing
    
    public static func create(
        from directoryURL: URL,
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        compressionLevel: Int? = nil,
        encryption: ArchiveEncryption? = nil,
        password: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        try shared.create(
            from: directoryURL,
            to: archiveURL,
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password,
            progress: progress
        )
    }
    
    public static func create(
        files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        compressionLevel: Int? = nil,
        encryption: ArchiveEncryption? = nil,
        password: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        try shared.create(
            files: files,
            to: archiveURL,
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password,
            progress: progress
        )
    }
    
    // MARK: - Format Detection
    
    public static func detectFormat(url: URL) throws -> (ArchiveFormat, ArchiveCompression) {
        try shared.detectFormat(url: url)
    }
    
    public static func isArchive(url: URL) -> Bool {
        shared.isArchive(url: url)
    }
}

// MARK: - ArchiveReader Convenience

extension ArchiveReader {
    
    /// Convenience alias for creating a reader
    public static func open(url: URL, password: String? = nil) throws -> ArchiveReader {
        try ArchiveReader(url: url, password: password)
    }
}
