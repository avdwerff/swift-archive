//
//  ArchiveCompression.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 29/12/2025.
//

import Foundation

/// Compression filters supported by SwiftArchive
public enum ArchiveCompression: String, CaseIterable, Sendable {
    case none
    case gzip
    case bzip2
    case xz
    case lzma
    case lz4
    case zstd
    case compress
    case lzip
    
    /// Initialize from libarchive filter code
    init(rawCode: Int32) {
        switch rawCode {
        case 0: self = .none
        case 1: self = .gzip
        case 2: self = .bzip2
        case 3: self = .compress
        case 5: self = .lzma
        case 6: self = .xz
        case 8: self = .lz4
        case 9: self = .lzip
        case 14: self = .zstd
        default: self = .none
        }
    }
    
    public var description: String {
        switch self {
        case .none: return "None"
        case .gzip: return "gzip"
        case .bzip2: return "bzip2"
        case .xz: return "xz"
        case .lzma: return "LZMA"
        case .lz4: return "LZ4"
        case .zstd: return "Zstandard"
        case .compress: return "compress (LZW)"
        case .lzip: return "lzip"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .none: return []
        case .gzip: return ["gz", "tgz"]
        case .bzip2: return ["bz2", "tbz2"]
        case .xz: return ["xz", "txz"]
        case .lzma: return ["lzma", "tlzma"]
        case .lz4: return ["lz4"]
        case .zstd: return ["zst"]
        case .compress: return ["Z"]
        case .lzip: return ["lz"]
        }
    }
}
