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
    case deflate
    case gzip
    case bzip2
    case xz
    case lzma
    case lzma2
    case lzip
    case lz4
    case lzop
    case zstd
    case compress
    
    public var isAvailable: Bool {
        switch self {
        case .none, .deflate, .gzip:
            return true
        case .bzip2:
        #if os(macOS)
            return true
        #else
            return false
        #endif
        case .lzma, .lzma2, .xz, .lz4, .lzip, .lzop, .zstd:
            return false  // Not bundled
        case .compress:
            return true
        }
    }
    
    /// All compression methods available on this platform
    public static var available: [ArchiveCompression] {
        allCases.filter { $0.isAvailable }
    }
    
    public var tarExtension: String? {
        switch self {
        case .none: return nil
        case .gzip: return "gz"
        case .bzip2: return "bz2"
        case .xz: return "xz"
        case .lzma: return "lzma"
        case .lzip: return "lz"
        case .lz4: return "lz4"
        case .lzop: return "lzo"
        case .zstd: return "zst"
        case .compress: return "Z"
        default: return nil
        }
    }
    
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .deflate: return "Deflate"
        case .gzip: return "Gzip"
        case .bzip2: return "Bzip2"
        case .xz: return "XZ"
        case .lzma: return "LZMA"
        case .lzma2: return "LZMA2"
        case .lzip: return "Lzip"
        case .lz4: return "LZ4"
        case .lzop: return "LZOP"
        case .zstd: return "Zstandard"
        case .compress: return "Compress (LZW)"
        }
    }
    
    public var compressionRatio: Int {
        switch self {
        case .none: return 0
        case .lz4: return 2
        case .lzop: return 3
        case .compress: return 3
        case .deflate, .gzip: return 5
        case .zstd: return 6
        case .bzip2: return 7
        case .lzma, .lzma2, .xz, .lzip: return 9
        }
    }
    
    public var speed: Int {
        switch self {
        case .none: return 10
        case .lz4: return 9
        case .lzop: return 8
        case .zstd: return 7
        case .deflate, .gzip: return 6
        case .compress: return 5
        case .bzip2: return 3
        case .lzma, .lzma2, .xz, .lzip: return 2
        }
    }
    
    /// Initialize from libarchive filter code
    init(code: Int32) {
        switch code {
        case 0: self = .none
        case 1: self = .gzip
        case 2: self = .bzip2
        case 3: self = .compress
        case 5: self = .lzma
        case 6: self = .xz
        case 8: self = .lz4
        case 9: self = .lzip
        case 10: self = .lzop
        case 14: self = .zstd
        default: self = .none
        }
    }
    
    public var description: String {
        switch self {
        case .none: return "None"
        case .deflate: return "deflate"
        case .gzip: return "gzip"
        case .bzip2: return "bzip2"
        case .xz: return "xz"
        case .lzma: return "LZMA"
        case .lzma2: return "LZMA2"
        case .lz4: return "LZ4"
        case .zstd: return "Zstandard"
        case .compress: return "compress (LZW)"
        case .lzip: return "lzip"
        case .lzop: return "lzop"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .none: return []
        case .deflate: return []  // Used internally in ZIP
        case .gzip: return ["gz", "tgz"]
        case .bzip2: return ["bz2", "tbz2", "tbz"]
        case .compress: return ["Z", "taz"]
        case .lzma: return ["lzma", "tlz"]
        case .lzma2: return []  // Used internally in 7z
        case .xz: return ["xz", "txz"]
        case .lz4: return ["lz4"]
        case .lzip: return ["lz"]
        case .lzop: return ["lzo"]
        case .zstd: return ["zst", "tzst"]
        }
    }
}
