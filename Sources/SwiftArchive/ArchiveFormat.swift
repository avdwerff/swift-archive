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
    case raw
    case unknown
    
    /// Initialize from libarchive format code
    init(rawCode: Int32) {
        let base = rawCode & 0xff0000
        switch base {
        case 0x50000: self = .zip
        case 0x30000: self = .tar
        case 0xE0000: self = .sevenZip
        case 0xD0000: self = .rar
        case 0x10000: self = .cpio
        case 0x40000: self = .iso9660
        case 0x70000: self = .ar
        case 0x60000: self = .cab
        case 0xC0000: self = .xar
        case 0x80000: self = .mtree
        case 0x90000: self = .raw
        default: self = .unknown
        }
    }
    
    public var description: String {
        switch self {
        case .zip: return "ZIP Archive"
        case .tar: return "Tape Archive (TAR)"
        case .sevenZip: return "7-Zip Archive"
        case .rar: return "RAR Archive"
        case .cpio: return "CPIO Archive"
        case .iso9660: return "ISO 9660 Disc Image"
        case .ar: return "Unix Archive"
        case .cab: return "Windows Cabinet"
        case .xar: return "Extensible Archive"
        case .mtree: return "mtree File Hierarchy"
        case .raw: return "Raw Data"
        case .unknown: return "Unknown Format"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .zip: return ["zip"]
        case .tar: return ["tar"]
        case .sevenZip: return ["7z"]
        case .rar: return ["rar"]
        case .cpio: return ["cpio"]
        case .iso9660: return ["iso"]
        case .ar: return ["a", "ar", "deb"]
        case .cab: return ["cab"]
        case .xar: return ["xar", "pkg"]
        case .mtree: return ["mtree"]
        case .raw: return []
        case .unknown: return []
        }
    }
    
    public var supportsWriting: Bool {
        switch self {
        case .zip, .tar, .cpio, .ar, .xar, .mtree, .raw:
            return true
        case .sevenZip, .rar, .iso9660, .cab, .unknown:
            return false
        }
    }
    
    public var isWritable: Bool {
        switch self {
        case .rar, .cab:
            return false
        default:
            return true
        }
    }
}


