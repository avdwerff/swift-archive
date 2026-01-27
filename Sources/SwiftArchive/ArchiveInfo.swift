//
//  ArchiveInfo.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 26/01/2026.
//

// MARK: - Archive Info

public struct ArchiveInfo: Sendable {
    public let format: ArchiveFormat
    public let compression: ArchiveCompression
    public let entryCount: Int
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    
    public var compressionRatio: Double {
        guard compressedSize > 0 else { return 1.0 }
        return Double(uncompressedSize) / Double(compressedSize)
    }
}
