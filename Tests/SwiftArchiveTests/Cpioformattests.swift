//
//  CPIOFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 24/03/2026.
//

import Testing
import Foundation
import CLibArchive
@testable import SwiftArchive

@Suite("CPIO Format Tests")
struct CPIOFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CPIOFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("CPIO format is readable")
    func cpioFormatIsReadable() {
        #expect(ArchiveFormat.cpio.canRead == true)
    }
    
    @Test("CPIO format is writable")
    func cpioFormatIsWritable() {
        #expect(ArchiveFormat.cpio.canWrite == true)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect CPIO format from file")
    func detectCPIOFormat() throws {
        let cpioURL = fixtureURL("test.cpio")
        let (format, _) = try Archive.detectFormat(url: cpioURL)
        
        #expect(format == .cpio)
    }
    
    @Test("CPIO file is recognized as archive")
    func cpioIsArchive() throws {
        let cpioURL = fixtureURL("test.cpio")
        
        #expect(Archive.isArchive(url: cpioURL) == true)
    }
    
    // MARK: - Archive Info
    
    @Test("Get CPIO archive info")
    func cpioArchiveInfo() throws {
        let cpioURL = fixtureURL("test.cpio")
        let info = try Archive.info(url: cpioURL)
        
        #expect(info.format == .cpio)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List CPIO archive contents")
    func cpioListContents() throws {
        let cpioURL = fixtureURL("test.cpio")
        let entries = try Archive.list(url: cpioURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test("CPIO archive contains files")
    func cpioContainsFiles() throws {
        let cpioURL = fixtureURL("test.cpio")
        let entries = try Archive.list(url: cpioURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Extraction
    
    @Test("Extract CPIO archive")
    func cpioExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cpioURL = fixtureURL("test.cpio")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: cpioURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract CPIO archive with progress")
    func cpioExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cpioURL = fixtureURL("test.cpio")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: cpioURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
    }
    
    @Test("Extract CPIO with overwrite")
    func cpioExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cpioURL = fixtureURL("test.cpio")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: cpioURL, to: outputDir)
        try Archive.extract(url: cpioURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    // MARK: - Single File Extraction
    
    @Test("Extract single file from CPIO")
    func cpioExtractSingleFile() throws {
        let cpioURL = fixtureURL("test.cpio")
        let entries = try Archive.list(url: cpioURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.cpio")
            return
        }
        
        let data = try Archive.extractFile(from: cpioURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    // MARK: - Round-trip (CPIO is writable)
    
    @Test("Round-trip CPIO archive")
    func cpioRoundTrip() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create test files
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        let file1 = sourceDir.appendingPathComponent("hello.txt")
        let file2 = sourceDir.appendingPathComponent("world.txt")
        try "Hello CPIO".write(to: file1, atomically: true, encoding: .utf8)
        try "World".write(to: file2, atomically: true, encoding: .utf8)
        
        // Create CPIO archive
        let archiveURL = tempDir.appendingPathComponent("roundtrip.cpio")
        try Archive.create(from: sourceDir, to: archiveURL, format: .cpio)
        
        // Verify format
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .cpio)
        
        // Extract and verify
        let extractDir = tempDir.appendingPathComponent("extracted")
        try Archive.extract(url: archiveURL, to: extractDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(!contents.isEmpty)
    }
    
    // MARK: - Debug
    
    @Test("Debug: CPIO format code")
    func debugCPIOFormatCode() throws {
        let cpioURL = fixtureURL("test.cpio")
        
        let archive = archive_read_new()
        defer { archive_read_free(archive) }
        
        archive_read_support_format_all(archive)
        archive_read_support_filter_all(archive)
        archive_read_open_filename(archive, cpioURL.path, 10240)
        
        var entry: OpaquePointer?
        archive_read_next_header(archive, &entry)
        
        let formatCode = archive_format(archive)
        let formatName = String(cString: archive_format_name(archive))
        
        print("Format code: \(formatCode) (hex: \(String(formatCode, radix: 16)))")
        print("Format name: \(formatName)")
    }
}
