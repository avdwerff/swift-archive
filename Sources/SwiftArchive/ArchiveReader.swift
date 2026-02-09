//
//  ArchiveReader.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 28/12/2025.
//

import Foundation
import CLibArchive

/// Thread-safe archive reader
final class ArchiveReader: Sendable {
    
    private let ARCHIVE_OK: Int32 = 0
    private let ARCHIVE_EOF: Int32 = 1
    private let ARCHIVE_WARN: Int32 = -20
    
    let url: URL
    private let password: String?
    
    init(url: URL, password: String? = nil) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ArchiveError.fileNotFound(url)
        }
        self.url = url
        self.password = password
    }
    
    var isEncrypted: Bool {
        let handle = try? ArchiveHandle(url: url, password: nil)
        defer { handle?.close() }
        
        if let entry = try? handle?.nextEntry() {
            return entry.isEncrypted
        }
        return false
    }
    
    /// Get archive info
    func info() throws -> ArchiveInfo {
        let handle = try ArchiveHandle(url: url, password: password)
        defer { handle.close() }
        
        var entryCount = 0
        var uncompressedSize: Int64 = 0
        var format: ArchiveFormat = .unknown
        var compression: ArchiveCompression = .none
        
        while let entry = try handle.nextEntry() {
            if format == .unknown {
                format = handle.format
                compression = handle.compression
            }
            entryCount += 1
            uncompressedSize += max(entry.size, 0)
        }
        
        let compressedSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        
        return ArchiveInfo(
            format: format,
            compression: compression,
            entryCount: entryCount,
            uncompressedSize: uncompressedSize,
            compressedSize: compressedSize
        )
    }
    
    /// List all entries
    func listEntries() throws -> [ArchiveEntry] {
        let handle = try ArchiveHandle(url: url, password: password)
        defer { handle.close() }
        
        var entries: [ArchiveEntry] = []
        while let entry = try handle.nextEntry() {
            entries.append(entry)
        }
        return entries
    }
    
    /// Iterate entries with handler
    func forEachEntry(_ handler: (ArchiveEntry) throws -> Void) throws {
        let handle = try ArchiveHandle(url: url, password: password)
        defer { handle.close() }
        
        while let entry = try handle.nextEntry() {
            try handler(entry)
        }
    }
    
    /// Extract a single entry by path
    func extract(path: String) throws -> Data? {
        let handle = try ArchiveHandle(url: url, password: password)
        defer { handle.close() }
        
        while let entry = try handle.nextEntry() {
            if entry.path == path {
                return try handle.readCurrentEntryData()
            }
        }
        return nil
    }
    
    /// Extract a single entry to file
    func extract(path: String, to destination: URL) throws -> Bool {
        guard let data = try extract(path: path) else {
            return false
        }
        try data.write(to: destination)
        return true
    }
    
    /// Extract all entries to destination
    func extractAll(
        to destination: URL,
        overwrite: Bool = false,
        progress: ((Double) -> Void)? = nil
    ) throws {
        // First pass: count total size
        let entries = try listEntries()
        let totalSize = entries.reduce(0) { $0 + max($1.size, 0) }
        
        // Second pass: extract
        let handle = try ArchiveHandle(url: url, password: password)
        defer { handle.close() }
        
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        
        var extractedSize: Int64 = 0
        
        while let entry = try handle.nextEntry() {
            let entryPath = entry.path
            
            guard !entryPath.contains("..") else {
                throw ArchiveError.unsafePath(path: entryPath)
            }
            
            let destPath = destination.appendingPathComponent(entryPath)
            
            switch entry.type {
            case .directory:
                try FileManager.default.createDirectory(at: destPath, withIntermediateDirectories: true)
                
            case .file:
                try FileManager.default.createDirectory(
                    at: destPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                if FileManager.default.fileExists(atPath: destPath.path) {
                    if overwrite {
                        try FileManager.default.removeItem(at: destPath)
                    } else {
                        throw ArchiveError.extractionFailed(path: entryPath, reason: "File already exists")
                    }
                }
                
                let data = try handle.readCurrentEntryData()
                try data.write(to: destPath)
                
                try FileManager.default.setAttributes(
                    [.posixPermissions: entry.permissions],
                    ofItemAtPath: destPath.path
                )
                
            case .symlink(let target):
                try FileManager.default.createSymbolicLink(
                    at: destPath,
                    withDestinationURL: URL(fileURLWithPath: target)
                )
                
            default:
                break
            }
            
            extractedSize += max(entry.size, 0)
            if totalSize > 0 {
                progress?(Double(extractedSize) / Double(totalSize))
            }
        }
        
        progress?(1.0)
    }
}

// MARK: - Internal Handle

private final class ArchiveHandle {
    private var archive: OpaquePointer?
    private(set) var format: ArchiveFormat = .unknown
    private(set) var compression: ArchiveCompression = .none
    
    init(url: URL, password: String?) throws {
        archive = archive_read_new()
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Failed to create archive")
        }
        
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)
        
        if let password {
            password.withCString { _ = archive_read_add_passphrase(archive, $0) }
        }
        
        let result = url.path.withCString { archive_read_open_filename(archive, $0, 10240) }
        
        guard result == ARCHIVE_OK else {
            let error = ArchiveError.from(archive: archive)
            archive_read_free(archive)
            self.archive = nil
            throw error
        }
    }
    
    deinit {
        close()
    }
    
    func close() {
        if let archive = archive {
            archive_read_free(archive)
            self.archive = nil
        }
    }
    
    func nextEntry() throws -> ArchiveEntry? {
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Archive not open")
        }
        
        var entryPtr: OpaquePointer?
        let result = archive_read_next_header(archive, &entryPtr)
        
        switch result {
        case ARCHIVE_OK, ARCHIVE_WARN:
            guard let entry = entryPtr else { return nil }
            if format == .unknown { detectFormat() }
            return ArchiveEntry(from: entry)
        case ARCHIVE_EOF:
            return nil
        default:
            throw ArchiveError.from(archive: archive)
        }
    }
    
    func readCurrentEntryData() throws -> Data {
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Archive not open")
        }
        
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        
        while true {
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                archive_read_data(archive, rawBuffer.baseAddress, rawBuffer.count)
            }
            
            if bytesRead < 0 {
                throw ArchiveError.from(archive: archive)
            }
            if bytesRead == 0 {
                break
            }
            
            result.append(contentsOf: buffer[..<Int(bytesRead)])
        }
        
        return result
    }
    
    private func detectFormat() {
        guard let archive = archive else { return }
        format = ArchiveFormat(code: archive_format(archive))
        if archive_filter_count(archive) > 0 {
            compression = ArchiveCompression(code: archive_filter_code(archive, 0))
        }
    }
}
