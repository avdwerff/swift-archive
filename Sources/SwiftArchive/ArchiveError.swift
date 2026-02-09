//
//  ArchiveError.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 10/01/2026.
//

import Foundation
import CLibArchive

// MARK: - POSIX error codes

private let ENOENT: Int32 = 2
private let EACCES: Int32 = 13
private let EPERM: Int32 = 1
private let ENOSPC: Int32 = 28


/// Errors that can occur during archive operations
public enum ArchiveError: Error, Sendable {
    /// The specified file was not found
    case fileNotFound(URL)
    
    /// The archive format is not supported or could not be detected
    case unsupportedFormat
    
    /// The archive appears to be corrupted or truncated
    case corruptedArchive(details: String)
    
    /// A password is required to read this archive
    case passwordRequired
    
    /// The provided password is incorrect
    case wrongPassword
    
    /// Failed to extract a specific entry
    case extractionFailed(path: String, reason: String)
    
    /// Failed to create/write archive
    case writeFailed(reason: String)
    
    /// Not enough disk space for extraction
    case insufficientSpace
    
    /// Permission denied when accessing file
    case permissionDenied(path: String)
    
    /// An entry path would escape the destination directory (zip slip attack)
    case unsafePath(path: String)
    
    /// Generic libarchive error
    case libarchiveError(code: Int32, message: String)
    
    /// The archive is empty or has no entries
    case emptyArchive
    
    /// Operation was cancelled
    case cancelled
    
    case encryptionNotSupported(ArchiveFormat)
    
    case encryptionRequired
    
    case invalidPassword
    
    case compressionNotAvailable(ArchiveCompression)
}

extension ArchiveError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .encryptionNotSupported(let format):
            return "Encryption is not supported for \(format.displayName)"
        case .passwordRequired:
            return "Password is required for encrypted archives"
        case .encryptionRequired:
            return "Encryption method must be specified when using a password"
        case .invalidPassword:
            return "Invalid password"
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .unsupportedFormat:
            return "Unsupported or unrecognized archive format"
        case .corruptedArchive(let details):
            return "Archive is corrupted: \(details)"
        case .wrongPassword:
            return "Incorrect password"
        case .extractionFailed(let path, let reason):
            return "Failed to extract '\(path)': \(reason)"
        case .writeFailed(let reason):
            return "Failed to write archive: \(reason)"
        case .insufficientSpace:
            return "Not enough disk space"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .unsafePath(let path):
            return "Unsafe path detected (potential zip slip): \(path)"
        case .libarchiveError(let code, let message):
            return "Archive error (\(code)): \(message)"
        case .emptyArchive:
            return "Archive is empty"
        case .cancelled:
            return "Operation was cancelled"
        case .compressionNotAvailable(let compression):
            return "\(compression.displayName) compression is not available on this platform"
        }
    }
}

// MARK: - Internal helpers for converting libarchive errors

extension ArchiveError {
    /// Create an ArchiveError from a libarchive archive pointer
    /// - Parameter archive: Pointer to the libarchive archive struct
    /// - Returns: An appropriate ArchiveError
    static func from(archive: OpaquePointer?) -> ArchiveError {
        guard let archive = archive else {
            return .libarchiveError(code: -1, message: "Invalid archive pointer")
        }
        
        let code = archive_errno(archive)
        let messagePtr = archive_error_string(archive)
        let message = messagePtr.map { String(cString: $0) } ?? "Unknown error"
        
        // Map common error codes to specific error types
        switch code {
        case 0:
            // Check if it's a password issue by looking at the message
            if message.lowercased().contains("passphrase") ||
                message.lowercased().contains("password") ||
                message.lowercased().contains("encrypted") {
                if message.lowercased().contains("incorrect") ||
                    message.lowercased().contains("wrong") {
                    return .wrongPassword
                }
                return .passwordRequired
            }
            return .libarchiveError(code: code, message: message)
            
        case ENOENT:
            return .libarchiveError(code: code, message: message)
            
        case EACCES, EPERM:
            return .permissionDenied(path: message)
            
        case ENOSPC:
            return .insufficientSpace
            
        default:
            // Check for corruption indicators
            if message.lowercased().contains("truncated") ||
                message.lowercased().contains("corrupt") ||
                message.lowercased().contains("invalid") {
                return .corruptedArchive(details: message)
            }
            
            return .libarchiveError(code: code, message: message)
        }
    }
}
