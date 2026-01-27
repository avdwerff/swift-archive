//
//  ArchiveEntry.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 10/01/2026.
//

import Foundation
import CLibArchive

/// Type of entry in an archive
public enum EntryType: Sendable, Equatable {
    case file
    case directory
    case symlink(target: String)
    
    // Rare cases (Unix)
    case hardlink(target: String)
    case blockDevice
    case characterDevice
    case fifo
    case socket
    case unknown
    
    /// Whether this entry type contains data (file contents)
    public var hasData: Bool {
        self == .file
    }
    
    /// Whether this entry represents a directory
    public var isDirectory: Bool {
        self == .directory
    }
    
    /// Whether this entry represents a symbolic link
    public var isSymlink: Bool {
        if case .symlink = self { return true }
        return false
    }
}

/// Represents a single entry (file, directory, etc.) in an archive
public struct ArchiveEntry: Sendable {
    /// Path of the entry within the archive
    public let path: String
    
    /// Type of entry (file, directory, symlink, etc.)
    public let type: EntryType
    
    /// Uncompressed size in bytes (0 for directories)
    public let size: Int64
    
    /// Compressed size in bytes (if available)
    public let compressedSize: Int64?
    
    /// Last modification date
    public let modificationDate: Date
    
    /// Creation date (if available)
    public let creationDate: Date?
    
    /// Access date (if available)
    public let accessDate: Date?
    
    /// POSIX permissions (e.g., 0o644)
    public let permissions: UInt16
    
    /// Owner user ID
    public let uid: UInt32
    
    /// Owner group ID
    public let gid: UInt32
    
    /// Owner username (if available)
    public let owner: String?
    
    /// Owner group name (if available)
    public let group: String?
    
    /// CRC32 checksum (if available, mainly for ZIP)
    public let crc32: UInt32?
    
    /// Whether this entry is encrypted
    public let isEncrypted: Bool
    
    // MARK: - Computed properties
    
    /// The filename component of the path
    public var filename: String {
        (path as NSString).lastPathComponent
    }
    
    /// The directory containing this entry
    public var directoryPath: String {
        (path as NSString).deletingLastPathComponent
    }
    
    /// File extension (empty string if none)
    public var pathExtension: String {
        (path as NSString).pathExtension
    }
    
    /// Human-readable permissions string (e.g., "rwxr-xr-x")
    public var permissionsString: String {
        var result = ""
        let perms = permissions
        
        // Owner
        result += (perms & 0o400) != 0 ? "r" : "-"
        result += (perms & 0o200) != 0 ? "w" : "-"
        result += (perms & 0o100) != 0 ? "x" : "-"
        
        // Group
        result += (perms & 0o040) != 0 ? "r" : "-"
        result += (perms & 0o020) != 0 ? "w" : "-"
        result += (perms & 0o010) != 0 ? "x" : "-"
        
        // Other
        result += (perms & 0o004) != 0 ? "r" : "-"
        result += (perms & 0o002) != 0 ? "w" : "-"
        result += (perms & 0o001) != 0 ? "x" : "-"
        
        return result
    }
}

// MARK: - Internal initializer from libarchive entry

extension ArchiveEntry {
    /// Create an ArchiveEntry from a libarchive archive_entry pointer
    init(from entry: OpaquePointer) {
        // Path
        if let pathPtr = archive_entry_pathname(entry) {
            self.path = String(cString: pathPtr)
        } else {
            self.path = ""
        }
        
        // Entry type
        let fileType = archive_entry_filetype(entry)
        switch Int32(fileType) {
        case AE_IFREG:
            self.type = .file
        case AE_IFDIR:
            self.type = .directory
        case AE_IFLNK:
            if let target = archive_entry_symlink(entry) {
                self.type = .symlink(target: String(cString: target))
            } else {
                self.type = .symlink(target: "")
            }
        case AE_IFBLK:
            self.type = .blockDevice
        case AE_IFCHR:
            self.type = .characterDevice
        case AE_IFIFO:
            self.type = .fifo
        case AE_IFSOCK:
            self.type = .socket
        default:
            // Check for hardlink
            if let hardlink = archive_entry_hardlink(entry) {
                self.type = .hardlink(target: String(cString: hardlink))
            } else {
                self.type = .unknown
            }
        }
        
        // Size
        self.size = archive_entry_size(entry)
        self.compressedSize = nil  // Not directly available per-entry
        
        // Dates
        if archive_entry_mtime_is_set(entry) != 0 {
            let mtime = archive_entry_mtime(entry)
            self.modificationDate = Date(timeIntervalSince1970: TimeInterval(mtime))
        } else {
            self.modificationDate = Date()
        }
        
        if archive_entry_birthtime_is_set(entry) != 0 {
            let btime = archive_entry_birthtime(entry)
            self.creationDate = Date(timeIntervalSince1970: TimeInterval(btime))
        } else {
            self.creationDate = nil
        }
        
        if archive_entry_atime_is_set(entry) != 0 {
            let atime = archive_entry_atime(entry)
            self.accessDate = Date(timeIntervalSince1970: TimeInterval(atime))
        } else {
            self.accessDate = nil
        }
        
        // Permissions
        self.permissions = UInt16(archive_entry_perm(entry) & 0o777)
        
        // Ownership
        self.uid = UInt32(archive_entry_uid(entry))
        self.gid = UInt32(archive_entry_gid(entry))
        
        if let uname = archive_entry_uname(entry) {
            self.owner = String(cString: uname)
        } else {
            self.owner = nil
        }
        
        if let gname = archive_entry_gname(entry) {
            self.group = String(cString: gname)
        } else {
            self.group = nil
        }
        
        // CRC32 (not directly available in libarchive entry)
        self.crc32 = nil
        
        // Encryption status
        self.isEncrypted = archive_entry_is_encrypted(entry) != 0
    }
}

// MARK: - CustomStringConvertible

extension ArchiveEntry: CustomStringConvertible {
    public var description: String {
        let typeChar: String
        switch type {
        case .file: typeChar = "-"
        case .directory: typeChar = "d"
        case .symlink: typeChar = "l"
        case .hardlink: typeChar = "h"
        case .blockDevice: typeChar = "b"
        case .characterDevice: typeChar = "c"
        case .fifo: typeChar = "p"
        case .socket: typeChar = "s"
        case .unknown: typeChar = "?"
        }
        
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        
        return "\(typeChar)\(permissionsString)  \(sizeStr.padding(toLength: 10, withPad: " ", startingAt: 0))  \(path)"
    }
}

// MARK: - libarchive constants

// File type constants from archive_entry.h
private let AE_IFREG: Int32  = 0o100000  // Regular file
private let AE_IFLNK: Int32  = 0o120000  // Symbolic link
private let AE_IFSOCK: Int32 = 0o140000  // Socket
private let AE_IFCHR: Int32  = 0o020000  // Character device
private let AE_IFBLK: Int32  = 0o060000  // Block device
private let AE_IFDIR: Int32  = 0o040000  // Directory
private let AE_IFIFO: Int32  = 0o010000  // Named pipe (FIFO)
