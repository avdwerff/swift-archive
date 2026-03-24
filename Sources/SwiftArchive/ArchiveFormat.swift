//
//  ArchiveFormat.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 29/12/2025.
//

import Foundation

/// Archive container formats supported by SwiftArchive
public enum ArchiveFormat: String, CaseIterable, Sendable {
    case zip
    case tar
    case sevenZip = "7z"
    case rar
    case cpio
    case iso9660
    case ar
    case cab
    case xar
    case mtree
    case lha
    case warc
    case shar
    case unknown
    
    /// Initialize from libarchive format code
    init(code: Int32) {
        switch code & 0xff0000 {
        case 0x50000: self = .zip
        case 0x30000: self = .tar
        case 0xE0000: self = .sevenZip
        case 0xD0000: self = .rar
        case 0x10000: self = .cpio
        case 0x40000: self = .iso9660
        case 0x70000: self = .ar
        case 0xC0000: self = .cab
        case 0xA0000: self = .xar
        case 0x80000: self = .mtree
        case 0xB0000: self = .lha
        case 0xF0000: self = .warc
        case 0x20000: self = .shar 
        default: self = .unknown
        }
    }
    
    public var canRead: Bool {
        switch self {
        case .shar, .unknown:
            return false
        default:
            return true
        }
    }
    
    public var readableEncryption: Set<ArchiveEncryption> {
        switch self {
        case .zip:
            return [.zipTraditional, .aes128, .aes192, .aes256]
        case .sevenZip:
            return [.aes256]
        case .rar:
            return [.aes256]
        default:
            return []
        }
    }
    
    public var writableEncryption: Set<ArchiveEncryption> {
        switch self {
        case .zip:
            return [.zipTraditional, .aes128, .aes192, .aes256]
        case .sevenZip:
            return []
        default:
            return []
        }
    }
    
    public var supportsEncryption: Bool {
        !writableEncryption.isEmpty
    }
    
    public var recommendedEncryption: ArchiveEncryption? {
        if writableEncryption.contains(.aes256) { return .aes256 }
        if writableEncryption.contains(.aes192) { return .aes192 }
        if writableEncryption.contains(.aes128) { return .aes128 }
        return nil
    }
    
    public var supportedCompression: Set<ArchiveCompression> {
        switch self {
        case .zip:
            return [.none, .deflate, .bzip2, .lzma, .xz, .zstd]
        case .tar:
            return [.none, .gzip, .bzip2, .xz, .lzma, .lz4, .zstd, .compress]
        case .sevenZip:
            return [.none, .lzma, .lzma2, .bzip2, .deflate, .zstd]
        case .cpio:
            return [.none, .gzip, .bzip2, .xz, .lzma, .zstd]
        case .xar:
            return [.none, .gzip, .bzip2, .lzma, .xz]
        case .ar:
            return [.none]
        case .iso9660:
            return [.none, .zstd]
        case .warc:
            return [.none, .gzip]
        case .shar:
            return [.none, .gzip, .bzip2, .xz]
        case .mtree:
            return [.none]
        default:
            return [.none]
        }
    }
    
    public var defaultCompression: ArchiveCompression {
        switch self {
        case .zip: return .deflate
        case .tar: return .none
        case .sevenZip: return .lzma2
        case .xar: return .gzip
        case .warc: return .gzip
        default: return .none
        }
    }
    
    public var displayName: String {
        switch self {
        case .zip: return "ZIP Archive"
        case .tar: return "Tape Archive"
        case .sevenZip: return "7-Zip Archive"
        case .rar: return "RAR Archive"
        case .cpio: return "CPIO Archive"
        case .iso9660: return "ISO 9660 Disc Image"
        case .ar: return "Unix Archive"
        case .cab: return "Windows Cabinet"
        case .xar: return "XAR Archive"
        case .mtree: return "mtree Manifest"
        case .lha: return "LHA Archive"
        case .warc: return "Web Archive"
        case .shar: return "Shell Archive"
        case .unknown: return "Unknown Format"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .zip: return ["zip", "zipx", "jar", "war", "ear", "ipa", "apk", "docx", "xlsx", "pptx"]
        case .tar: return ["tar"]
        case .sevenZip: return ["7z"]
        case .rar: return ["rar"]
        case .cpio: return ["cpio"]
        case .iso9660: return ["iso"]
        case .ar: return ["a", "ar", "deb"]
        case .cab: return ["cab"]
        case .xar: return ["xar", "pkg"]
        case .mtree: return ["mtree"]
        case .lha: return ["lha", "lzh"]
        case .warc: return ["warc"]
        case .shar: return ["shar", "sh"]
        case .unknown: return []
        }
    }
    
    public var mimeTypes: [String] {
        switch self {
        case .zip: return ["application/zip", "application/x-zip-compressed"]
        case .tar: return ["application/x-tar"]
        case .sevenZip: return ["application/x-7z-compressed"]
        case .rar: return ["application/vnd.rar", "application/x-rar-compressed"]
        case .cpio: return ["application/x-cpio"]
        case .iso9660: return ["application/x-iso9660-image"]
        case .ar: return ["application/x-archive", "application/x-deb"]
        case .cab: return ["application/vnd.ms-cab-compressed"]
        case .xar: return ["application/x-xar"]
        case .mtree: return ["text/plain"]
        case .lha: return ["application/x-lha", "application/x-lzh-compressed"]
        case .warc: return ["application/warc"]
        case .shar: return ["application/x-shar"]
        case .unknown: return ["application/octet-stream"]
        }
    }
    
    public static func from(extension ext: String) -> ArchiveFormat {
        let lower = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        for format in ArchiveFormat.allCases where format != .unknown {
            if format.fileExtensions.contains(lower) {
                return format
            }
        }
        return .unknown
    }
    
    public static func from(mimeType: String) -> ArchiveFormat {
        let lower = mimeType.lowercased()
        for format in ArchiveFormat.allCases where format != .unknown {
            if format.mimeTypes.contains(lower) {
                return format
            }
        }
        return .unknown
    }
    
    public var canWrite: Bool {
        switch self {
        case .zip, .tar, .cpio, .ar, .mtree, .warc, .shar:
            return true
        case .sevenZip:
            return true  // 7z has internal LZMA
        case .xar, .iso9660:
            return false  // Needs LZMA
        case .rar, .lha, .cab, .unknown:
            return false  // Read-only
        }
    }
}


