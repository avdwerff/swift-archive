//
//  MtreeFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 24/03/2026.
//

import Testing
import Foundation
import CLibArchive
@testable import SwiftArchive

@Suite("Mtree Format Tests")
struct MtreeFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MtreeFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("Mtree format is readable")
    func mtreeFormatIsReadable() {
        #expect(ArchiveFormat.mtree.canRead == true)
    }
    
    @Test("Mtree format is writable")
    func mtreeFormatIsWritable() {
        #expect(ArchiveFormat.mtree.canWrite == true)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect mtree format from file")
    func detectMtreeFormat() throws {
        let mtreeURL = fixtureURL("test.mtree")
        let (format, _) = try Archive.detectFormat(url: mtreeURL)
        
        #expect(format == .mtree)
    }
    
    @Test("Mtree file is recognized as archive")
    func mtreeIsArchive() throws {
        let mtreeURL = fixtureURL("test.mtree")
        
        #expect(Archive.isArchive(url: mtreeURL) == true)
    }
    
    // MARK: - Archive Info
    
    @Test("Get mtree archive info")
    func mtreeArchiveInfo() throws {
        let mtreeURL = fixtureURL("test.mtree")
        let info = try Archive.info(url: mtreeURL)
        
        #expect(info.format == .mtree)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List mtree archive contents")
    func mtreeListContents() throws {
        let mtreeURL = fixtureURL("test.mtree")
        let entries = try Archive.list(url: mtreeURL)
        
        #expect(!entries.isEmpty)
    }
    
    // MARK: - Debug
    
    @Test("Debug: Mtree format code")
    func debugMtreeFormatCode() throws {
        let mtreeURL = fixtureURL("test.mtree")
        
        let archive = archive_read_new()
        defer { archive_read_free(archive) }
        
        archive_read_support_format_all(archive)
        archive_read_support_filter_all(archive)
        archive_read_open_filename(archive, mtreeURL.path, 10240)
        
        var entry: OpaquePointer?
        archive_read_next_header(archive, &entry)
        
        let formatCode = archive_format(archive)
        let formatName = String(cString: archive_format_name(archive))
        
        print("Format code: \(formatCode) (hex: \(String(formatCode, radix: 16)))")
        print("Format name: \(formatName)")
    }
}
