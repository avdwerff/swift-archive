//
//  ArchiveWriter.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 11/01/2026.
//

import Foundation
import CLibArchive


// MARK: - Constants

private let AE_IFREG: UInt32 = 0o100000
private let AE_IFLNK: UInt32 = 0o120000
private let AE_IFDIR: UInt32 = 0o040000

private let ARCHIVE_OK: Int32 = 0


final class ArchiveWriter: Sendable {
    
    // MARK: - Properties
    
    let url: URL
    let format: ArchiveFormat
    let compression: ArchiveCompression
    let compressionLevel: Int?
    let encryption: ArchiveEncryption?
    let password: String?
    
    // MARK: - Initialization
    
    /// Create a new archive writer
    /// - Parameters:
    ///   - url: Destination URL for the archive
    ///   - format: Archive format (default: .zip)
    ///   - compression: Compression method (default: .deflate for zip, .none for others)
    ///   - encryption: Encryption method (optional)
    ///   - password: Password for encryption (required if encryption is set)
    init(
        url: URL,
        format: ArchiveFormat = .zip,
        compression: ArchiveCompression? = nil,
        compressionLevel: Int? = nil,
        encryption: ArchiveEncryption? = nil,
        password: String? = nil
    ) {
        self.url = url
        self.format = format
        self.compression = compression ?? Self.defaultCompression(for: format)
        self.compressionLevel = compressionLevel
        self.encryption = encryption
        self.password = password
    }
    
    /// Write archive using a builder closure
    /// - Parameter builder: Closure that receives a WriteContext to add entries
    func write(_ builder: (WriteContext) throws -> Void) throws {
        let handle = try WriteHandle(
            url: url,
            format: format,
            compression: compression,
            compressionLevel: compressionLevel,
            encryption: encryption,
            password: password
        )
        let context = WriteContext(handle: handle)
        
        do {
            try builder(context)
            try handle.finalize()
        } catch {
            handle.close()
            throw error
        }
    }
    
    /// Add a single file from disk
    func addFile(at fileURL: URL, archivePath: String? = nil) throws {
        try write { context in
            try context.addFile(at: fileURL, archivePath: archivePath)
        }
    }
    
    /// Add a single file from Data
    func addFile(path: String, data: Data, permissions: UInt16 = 0o644) throws {
        try write { context in
            try context.addFile(path: path, data: data, permissions: permissions)
        }
    }
    
    /// Add an entire directory recursively
    func addDirectory(
        at directoryURL: URL,
        basePath: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        try write { context in
            try context.addDirectory(at: directoryURL, basePath: basePath, progress: progress)
        }
    }
    
    /// Add multiple files
    func addFiles(_ files: [URL], progress: ((Double) -> Void)? = nil) throws {
        try write { context in
            let total = Double(files.count)
            for (index, file) in files.enumerated() {
                try context.addFile(at: file)
                progress?(Double(index + 1) / total)
            }
        }
    }
    
    // MARK: - Private
    
    private static func defaultCompression(for format: ArchiveFormat) -> ArchiveCompression {
        switch format {
        case .sevenZip:
            return .lzma
        default:
            return .none
        }
    }
}

// MARK: - Write Context

final class WriteContext {
    
    private let handle: WriteHandle
    
    fileprivate init(handle: WriteHandle) {
        self.handle = handle
    }
    
    /// Add a file from disk
    func addFile(at fileURL: URL, archivePath: String? = nil) throws {
        let data = try Data(contentsOf: fileURL)
        let path = archivePath ?? fileURL.lastPathComponent
        
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? Int) ?? 0o644
        let modificationDate = (attributes[.modificationDate] as? Date) ?? Date()
        
        try addFile(
            path: path,
            data: data,
            permissions: UInt16(permissions),
            modificationDate: modificationDate
        )
    }
    
    /// Add a file from Data
    func addFile(
        path: String,
        data: Data,
        permissions: UInt16 = 0o644,
        modificationDate: Date = Date()
    ) throws {
        try handle.addFile(
            path: path,
            data: data,
            permissions: permissions,
            modificationDate: modificationDate
        )
    }
    
    /// Add a directory entry
    func addDirectory(path: String, permissions: UInt16 = 0o755) throws {
        try handle.addDirectory(path: path, permissions: permissions)
    }
    
    /// Add a symbolic link
    func addSymlink(path: String, target: String) throws {
        try handle.addSymlink(path: path, target: target)
    }
    
    /// Add an entire directory recursively
    func addDirectory(
        at directoryURL: URL,
        basePath: String? = nil,
        progress: ((URL, Double) throws -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        let base = basePath ?? directoryURL.lastPathComponent
        
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ArchiveError.libarchiveError(code: -1, message: "Cannot enumerate directory")
        }
        
        var items: [(url: URL, relativePath: String)] = []
        
        while let itemURL = enumerator.nextObject() as? URL {
            let relativePath = itemURL.path.replacingOccurrences(
                of: directoryURL.path + "/",
                with: ""
            )
            items.append((itemURL, relativePath))
        }
        
        let totalCount = Double(items.count)
        
        for (index, item) in items.enumerated() {
            let archivePath = base + "/" + item.relativePath
            
            let resourceValues = try item.url.resourceValues(forKeys: [.isDirectoryKey])
            
            if resourceValues.isDirectory == true {
                try addDirectory(path: archivePath)
            } else {
                try addFile(at: item.url, archivePath: archivePath)
            }
            
            try progress?(item.url, Double(index + 1) / totalCount)
        }
    }
}

// MARK: - Internal Handle

private final class WriteHandle {
    
    private var archive: OpaquePointer?
    
    init(
        url: URL,
        format: ArchiveFormat,
        compression: ArchiveCompression,
        compressionLevel: Int?,
        encryption: ArchiveEncryption?,
        password: String?
    ) throws {
        archive = archive_write_new()
        guard let archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Failed to create archive writer")
        }
        
        // Set format
        let formatResult = setFormat(archive, format: format)
        guard formatResult == ARCHIVE_OK else {
            let error = ArchiveError.from(archive: archive)
            archive_write_free(archive)
            self.archive = nil
            throw error
        }
        
        // Set compression
        let compressionResult = setCompression(
            archive,
            compression: compression,
            format: format,
            level: compressionLevel
        )
        guard compressionResult == ARCHIVE_OK else {
            let error = ArchiveError.from(archive: archive)
            archive_write_free(archive)
            self.archive = nil
            throw error
        }
        
        // Set encryption (if provided)
        if let encryption, let password {
            try setEncryption(archive, encryption: encryption, password: password, format: format)
        }
        
        // Open file
        let openResult = url.path.withCString { path in
            archive_write_open_filename(archive, path)
        }
        
        guard openResult == ARCHIVE_OK else {
            let error = ArchiveError.from(archive: archive)
            archive_write_free(archive)
            self.archive = nil
            throw error
        }
    }
    
    deinit {
        close()
    }
    
    func addFile(
        path: String,
        data: Data,
        permissions: UInt16,
        modificationDate: Date
    ) throws {
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Archive not open")
        }
        
        let entry = archive_entry_new()
        defer { archive_entry_free(entry) }
        
        path.withCString { pathPtr in
            archive_entry_set_pathname(entry, pathPtr)
        }
        
        archive_entry_set_size(entry, Int64(data.count))
        archive_entry_set_filetype(entry, UInt32(AE_IFREG))
        archive_entry_set_perm(entry, mode_t(permissions))
        archive_entry_set_mtime(entry, Int(modificationDate.timeIntervalSince1970), 0)
        
        let headerResult = archive_write_header(archive, entry)
        guard headerResult == ARCHIVE_OK else {
            throw ArchiveError.from(archive: archive)
        }
        
        try data.withUnsafeBytes { buffer in
            let written = archive_write_data(archive, buffer.baseAddress, buffer.count)
            if written < 0 {
                throw ArchiveError.from(archive: archive)
            }
        }
    }
    
    func addDirectory(path: String, permissions: UInt16) throws {
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Archive not open")
        }
        
        let entry = archive_entry_new()
        defer { archive_entry_free(entry) }
        
        let dirPath = path.hasSuffix("/") ? path : path + "/"
        
        dirPath.withCString { pathPtr in
            archive_entry_set_pathname(entry, pathPtr)
        }
        
        archive_entry_set_size(entry, 0)
        archive_entry_set_filetype(entry, UInt32(AE_IFDIR))
        archive_entry_set_perm(entry, mode_t(permissions))
        archive_entry_set_mtime(entry, Int(Date().timeIntervalSince1970), 0)
        
        let headerResult = archive_write_header(archive, entry)
        guard headerResult == ARCHIVE_OK else {
            throw ArchiveError.from(archive: archive)
        }
    }
    
    func addSymlink(path: String, target: String) throws {
        guard let archive = archive else {
            throw ArchiveError.libarchiveError(code: -1, message: "Archive not open")
        }
        
        let entry = archive_entry_new()
        defer { archive_entry_free(entry) }
        
        path.withCString { pathPtr in
            archive_entry_set_pathname(entry, pathPtr)
        }
        
        target.withCString { targetPtr in
            archive_entry_set_symlink(entry, targetPtr)
        }
        
        archive_entry_set_size(entry, 0)
        archive_entry_set_filetype(entry, UInt32(AE_IFLNK))
        archive_entry_set_perm(entry, mode_t(0o777))
        
        let headerResult = archive_write_header(archive, entry)
        guard headerResult == ARCHIVE_OK else {
            throw ArchiveError.from(archive: archive)
        }
    }
    
    func finalize() throws {
        guard let archive = archive else { return }
        
        let result = archive_write_close(archive)
        if result != ARCHIVE_OK {
            let error = ArchiveError.from(archive: archive)
            archive_write_free(archive)
            self.archive = nil
            throw error
        }
        
        archive_write_free(archive)
        self.archive = nil
    }
    
    func close() {
        if let archive = archive {
            archive_write_free(archive)
            self.archive = nil
        }
    }
    
    // MARK: - Private Configuration
    
    private func setFormat(_ archive: OpaquePointer, format: ArchiveFormat) -> Int32 {
        switch format {
        case .zip:
            return archive_write_set_format_zip(archive)
        case .tar:
            return archive_write_set_format_gnutar(archive)
        case .cpio:
            return archive_write_set_format_cpio(archive)
        case .sevenZip:
            return archive_write_set_format_7zip(archive)
        case .iso9660:
            return archive_write_set_format_iso9660(archive)
        case .xar:
            return archive_write_set_format_xar(archive)
        case .ar:
            return archive_write_set_format_ar_svr4(archive)
        case .mtree:
            return archive_write_set_format_mtree(archive)
        case .warc:
            return archive_write_set_format_warc(archive)
        case .shar:
            return archive_write_set_format_shar(archive)
        case .rar, .lha, .cab, .unknown:
            // Fallback to zip for unsupported write formats
            return archive_write_set_format_zip(archive)
        }
    }
    
    private func setCompression(
        _ archive: OpaquePointer,
        compression: ArchiveCompression,
        format: ArchiveFormat,
        level: Int? = nil
    ) -> Int32 {
        let validLevel = level.map { max(1, min(9, $0)) }
        
        // ZIP handles compression internally via options
        if format == .zip {
            var options: [String] = []
            
            switch compression {
            case .none:
                options.append("zip:compression=store")
            case .bzip2:
                options.append("zip:compression=bzip2")
            case .lzma:
                options.append("zip:compression=lzma")
            case .xz:
                options.append("zip:compression=xz")
            case .zstd:
                options.append("zip:compression=zstd")
            default:
                options.append("zip:compression=deflate")
            }
            
            if let level = validLevel, compression != .none {
                options.append("zip:compression-level=\(level)")
            }
            
            return archive_write_set_options(archive, options.joined(separator: ","))
        }
        
        // 7z handles compression internally
        if format == .sevenZip {
            if let level = validLevel {
                return archive_write_set_options(archive, "7zip:compression-level=\(level)")
            }
            return ARCHIVE_OK
        }
        
        // Other formats use filters
        var result: Int32
        switch compression {
        case .none, .deflate:
            result = archive_write_add_filter_none(archive)
        case .gzip:
            result = archive_write_add_filter_gzip(archive)
        case .bzip2:
            result = archive_write_add_filter_bzip2(archive)
        case .compress:
            result = archive_write_add_filter_compress(archive)
        default:
            result = archive_write_add_filter_none(archive)
        }
        
        // Set compression level for filters
        if let level = validLevel, result == ARCHIVE_OK, compression != .none {
            let levelOption: String?
            switch compression {
            case .gzip:
                levelOption = "gzip:compression-level=\(level)"
            case .bzip2:
                levelOption = "bzip2:compression-level=\(level)"
            default:
                levelOption = nil
            }
            
            if let option = levelOption {
                return archive_write_set_options(archive, option)
            }
        }
        
        return result
    }
    
    private func setEncryption(_ archive: OpaquePointer, encryption: ArchiveEncryption, password: String, format: ArchiveFormat) throws {
        // Set passphrase
        let passphraseResult = password.withCString { pwd in
            archive_write_set_passphrase(archive, pwd)
        }
        
        guard passphraseResult == ARCHIVE_OK else {
            throw ArchiveError.from(archive: archive)
        }
        
        // Set encryption option based on format
        let option: String
        switch format {
        case .zip:
            switch encryption {
            case .zipTraditional:
                option = "zip:encryption=zipcrypt"
            case .aes128:
                option = "zip:encryption=aes128"
            case .aes192:
                option = "zip:encryption=aes192"
            case .aes256:
                option = "zip:encryption=aes256"
            }
        case .sevenZip:
            // 7z only supports AES-256
            option = "7zip:compression=lzma2"  // encryption is automatic when passphrase is set
            // Note: 7z encryption is enabled automatically when passphrase is set
            return
        default:
            throw ArchiveError.encryptionNotSupported(format)
        }
        
        let optionResult = archive_write_set_options(archive, option)
        guard optionResult == ARCHIVE_OK else {
            throw ArchiveError.from(archive: archive)
        }
    }
}
