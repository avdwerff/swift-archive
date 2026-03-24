//
//  ISOFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 24/03/2026.
//

import Testing
import Foundation
import CLibArchive
@testable import SwiftArchive

@Suite("ISO Format Tests")
struct ISOFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ISOFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("ISO format is readable")
    func isoFormatIsReadable() {
        #expect(ArchiveFormat.iso9660.canRead == true)
    }
    
    @Test("ISO format is not writable")
    func isoFormatIsNotWritable() {
        #expect(ArchiveFormat.iso9660.canWrite == false)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect ISO format from file")
    func detectISOFormat() throws {
        let isoURL = fixtureURL("test.iso")
        let (format, _) = try Archive.detectFormat(url: isoURL)
        
        #expect(format == .iso9660)
    }
    
    @Test("ISO file is recognized as archive")
    func isoIsArchive() throws {
        let isoURL = fixtureURL("test.iso")
        
        #expect(Archive.isArchive(url: isoURL) == true)
    }
    
    // MARK: - Archive Info
    
    @Test("Get ISO archive info")
    func isoArchiveInfo() throws {
        let isoURL = fixtureURL("test.iso")
        let info = try Archive.info(url: isoURL)
        
        #expect(info.format == .iso9660)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List ISO archive contents")
    func isoListContents() throws {
        let isoURL = fixtureURL("test.iso")
        let entries = try Archive.list(url: isoURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test("ISO archive contains files")
    func isoContainsFiles() throws {
        let isoURL = fixtureURL("test.iso")
        let entries = try Archive.list(url: isoURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Extraction
    
    @Test("Extract ISO archive")
    func isoExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isoURL = fixtureURL("test.iso")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: isoURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract ISO archive with progress")
    func isoExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isoURL = fixtureURL("test.iso")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: isoURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
        
        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
    }
    
    @Test("Extract ISO with overwrite")
    func isoExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isoURL = fixtureURL("test.iso")
        let outputDir = tempDir.appendingPathComponent("output")
        
        // Extract twice with overwrite
        try Archive.extract(url: isoURL, to: outputDir)
        try Archive.extract(url: isoURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract ISO fails without overwrite")
    func isoExtractFailsWithoutOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isoURL = fixtureURL("test.iso")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: isoURL, to: outputDir)
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: isoURL, to: outputDir, overwrite: false)
        }
    }
    
    // MARK: - Single File Extraction
    
    @Test("Extract single file from ISO")
    func isoExtractSingleFile() throws {
        let isoURL = fixtureURL("test.iso")
        let entries = try Archive.list(url: isoURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.iso")
            return
        }
        
        let data = try Archive.extractFile(from: isoURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    @Test("Extract nonexistent file from ISO returns nil")
    func isoExtractNonexistentFile() throws {
        let isoURL = fixtureURL("test.iso")
        let data = try Archive.extractFile(from: isoURL, path: "nonexistent.txt")
        
        #expect(data == nil)
    }
    
    // MARK: - ArchiveReader Tests
    
    @Test("Open ISO with ArchiveReader")
    func isoArchiveReaderOpen() throws {
        let isoURL = fixtureURL("test.iso")
        let reader = try ArchiveReader.open(url: isoURL)
        
        #expect(reader.url == isoURL)
    }
    
    // MARK: - Concurrent Access
    
    @Test("Concurrent ISO reads")
    func isoConcurrentReads() async throws {
        let isoURL = fixtureURL("test.iso")
        
        async let info1 = Task.detached { try Archive.info(url: isoURL) }.value
        async let info2 = Task.detached { try Archive.info(url: isoURL) }.value
        async let info3 = Task.detached { try Archive.info(url: isoURL) }.value
        
        let results = try await [info1, info2, info3]
        
        #expect(results.allSatisfy { $0.format == .iso9660 })
    }
    
    // MARK: - Debug
    
    @Test("Debug: ISO format code")
    func debugISOFormatCode() throws {
        let isoURL = fixtureURL("test.iso")
        
        let archive = archive_read_new()
        defer { archive_read_free(archive) }
        
        archive_read_support_format_all(archive)
        archive_read_support_filter_all(archive)
        archive_read_open_filename(archive, isoURL.path, 10240)
        
        var entry: OpaquePointer?
        archive_read_next_header(archive, &entry)
        
        let formatCode = archive_format(archive)
        let formatName = String(cString: archive_format_name(archive))
        
        print("Format code: \(formatCode) (hex: \(String(formatCode, radix: 16)))")
        print("Format name: \(formatName)")
    }
}
