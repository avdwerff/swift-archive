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
/// let reader = try ArchiveReader(url: fileURL)
/// let entries = try reader.listEntries()
/// for entry in entries {
///     print(entry.path)
/// }
///
/// try reader.extractAll(to: destinationURL)
///
/// if let data = try reader.extract(path: "README.md") {
///     print(String(data: data, encoding: .utf8)!)
/// }
/// ```
///
/// ## Writing Archives
///
/// ```swift
/// let writer = ArchiveWriter(url: archiveURL, format: .zip)
/// try writer.write { context in
///     try context.addFile(path: "hello.txt", data: helloData)
///     try context.addDirectory(at: sourceDir)
/// }
/// ```
///
/// ## Quick Operations
///
/// ```swift
/// // Info
/// let info = try Archive.info(url: fileURL)
///
/// // Extract
/// try Archive.extract(url: archiveURL, to: destinationURL)
///
/// // Create
/// try Archive.create(from: sourceDir, to: archiveURL)
/// ```
///
public enum Archive {
    
    // MARK: - Reading
    
    /// Get archive information without fully reading the archive
    public static func info(url: URL, password: String? = nil) throws -> ArchiveInfo {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.info()
    }
    
    /// List all entries in an archive
    public static func list(url: URL, password: String? = nil) throws -> [ArchiveEntry] {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.listEntries()
    }
    
    /// Extract all entries from an archive
    public static func extract(
        url: URL,
        to destination: URL,
        password: String? = nil,
        overwrite: Bool = false,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let reader = try ArchiveReader(url: url, password: password)
        try reader.extractAll(
            to: destination,
            overwrite: overwrite,
            progress: progress
        )
    }
    
    /// Extract a single file from an archive
    public static func extractFile(
        from url: URL,
        path entryPath: String,
        password: String? = nil
    ) throws -> Data? {
        let reader = try ArchiveReader(url: url, password: password)
        return try reader.extract(path: entryPath)
    }
    
    // MARK: - Writing
    
    /// Create an archive from a directory
    public static func create(
        from directoryURL: URL,
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let writer = ArchiveWriter(url: archiveURL, format: format, compression: compression)
        try writer.addDirectory(at: directoryURL, progress: progress)
    }
    
    /// Create an archive from multiple files
    public static func create(
        files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let writer = ArchiveWriter(url: archiveURL, format: format, compression: compression)
        try writer.addFiles(files, progress: progress)
    }
    
    // MARK: - Format Detection
    
    /// Detect the format of an archive
    public static func detectFormat(url: URL) throws -> (ArchiveFormat, ArchiveCompression) {
        let info = try info(url: url)
        return (info.format, info.compression)
    }
    
    /// Check if a file is a supported archive
    public static func isArchive(url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        do {
            _ = try info(url: url)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - ArchiveReader Convenience

extension ArchiveReader {
    
    /// Convenience alias for creating a reader
    public static func open(url: URL, password: String? = nil) throws -> ArchiveReader {
        try ArchiveReader(url: url, password: password)
    }
}

// MARK: - ArchiveWriter Convenience

extension ArchiveWriter {
    
    /// Create an archive from a directory
    public static func archive(
        directory directoryURL: URL,
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let writer = ArchiveWriter(url: archiveURL, format: format, compression: compression)
        try writer.addDirectory(at: directoryURL, progress: progress)
    }
    
    /// Create an archive from multiple files
    public static func archive(
        files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        progress: ((Double) -> Void)? = nil
    ) throws {
        let writer = ArchiveWriter(url: archiveURL, format: format, compression: compression)
        try writer.addFiles(files, progress: progress)
    }
}

// MARK: - URL Extension

extension URL {
    
    /// Check if this URL points to a supported archive
    public var isArchive: Bool {
        Archive.isArchive(url: self)
    }
    
    /// Get archive info
    public func archiveInfo(password: String? = nil) throws -> ArchiveInfo {
        try Archive.info(url: self, password: password)
    }
    
    /// List entries in the archive
    public func archiveEntries(password: String? = nil) throws -> [ArchiveEntry] {
        try Archive.list(url: self, password: password)
    }
    
    /// Extract the archive
    public func extractArchive(
        to destination: URL,
        password: String? = nil,
        overwrite: Bool = false,
        progress: ((Double) -> Void)? = nil
    ) throws {
        try Archive.extract(
            url: self,
            to: destination,
            password: password,
            overwrite: overwrite,
            progress: progress
        )
    }
    
    /// Create an archive from this directory
    public func createArchive(
        at archiveURL: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        progress: ((Double) -> Void)? = nil
    ) throws {
        try Archive.create(
            from: self,
            to: archiveURL,
            format: format,
            compression: compression,
            progress: progress
        )
    }
}
