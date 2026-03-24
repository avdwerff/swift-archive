//
//  LHAFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 24/03/2026.
//

import Testing
import Foundation
import CLibArchive
@testable import SwiftArchive

@Suite("LHA Format Tests")
struct LHAFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LHAFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("LHA format is readable")
    func lhaFormatIsReadable() {
        #expect(ArchiveFormat.lha.canRead == true)
    }
    
    @Test("LHA format is not writable")
    func lhaFormatIsNotWritable() {
        #expect(ArchiveFormat.lha.canWrite == false)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect LHA format from file")
    func detectLHAFormat() throws {
        let lhaURL = fixtureURL("test.lha")
        let (format, _) = try Archive.detectFormat(url: lhaURL)
        
        #expect(format == .lha)
    }
    
    @Test("LHA file is recognized as archive")
    func lhaIsArchive() throws {
        let lhaURL = fixtureURL("test.lha")
        
        #expect(Archive.isArchive(url: lhaURL) == true)
    }
    
    // MARK: - Archive Info
    
    @Test("Get LHA archive info")
    func lhaArchiveInfo() throws {
        let lhaURL = fixtureURL("test.lha")
        let info = try Archive.info(url: lhaURL)
        
        #expect(info.format == .lha)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List LHA archive contents")
    func lhaListContents() throws {
        let lhaURL = fixtureURL("test.lha")
        let entries = try Archive.list(url: lhaURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test("LHA archive contains files")
    func lhaContainsFiles() throws {
        let lhaURL = fixtureURL("test.lha")
        let entries = try Archive.list(url: lhaURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Extraction
    
    @Test("Extract LHA archive")
    func lhaExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let lhaURL = fixtureURL("test.lha")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: lhaURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract LHA archive with progress")
    func lhaExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let lhaURL = fixtureURL("test.lha")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: lhaURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
        
        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
    }
    
    @Test("Extract LHA with overwrite")
    func lhaExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let lhaURL = fixtureURL("test.lha")
        let outputDir = tempDir.appendingPathComponent("output")
        
        // Extract twice with overwrite
        try Archive.extract(url: lhaURL, to: outputDir)
        try Archive.extract(url: lhaURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract LHA fails without overwrite")
    func lhaExtractFailsWithoutOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let lhaURL = fixtureURL("test.lha")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: lhaURL, to: outputDir)
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: lhaURL, to: outputDir, overwrite: false)
        }
    }
    
    // MARK: - Single File Extraction
    
    @Test("Extract single file from LHA")
    func lhaExtractSingleFile() throws {
        let lhaURL = fixtureURL("test.lha")
        let entries = try Archive.list(url: lhaURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.lha")
            return
        }
        
        let data = try Archive.extractFile(from: lhaURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    @Test("Extract nonexistent file from LHA returns nil")
    func lhaExtractNonexistentFile() throws {
        let lhaURL = fixtureURL("test.lha")
        let data = try Archive.extractFile(from: lhaURL, path: "nonexistent.txt")
        
        #expect(data == nil)
    }
    
    // MARK: - ArchiveReader Tests
    
    @Test("Open LHA with ArchiveReader")
    func lhaArchiveReaderOpen() throws {
        let lhaURL = fixtureURL("test.lha")
        let reader = try ArchiveReader.open(url: lhaURL)
        
        #expect(reader.url == lhaURL)
    }
    
    // MARK: - Concurrent Access
    
    @Test("Concurrent LHA reads")
    func lhaConcurrentReads() async throws {
        let lhaURL = fixtureURL("test.lha")
        
        async let info1 = Task.detached { try Archive.info(url: lhaURL) }.value
        async let info2 = Task.detached { try Archive.info(url: lhaURL) }.value
        async let info3 = Task.detached { try Archive.info(url: lhaURL) }.value
        
        let results = try await [info1, info2, info3]
        
        #expect(results.allSatisfy { $0.format == .lha })
    }
    
    // MARK: - Debug
    
    @Test("Debug: LHA format code")
    func debugLHAFormatCode() throws {
        let lhaURL = fixtureURL("test.lha")
        
        let archive = archive_read_new()
        defer { archive_read_free(archive) }
        
        archive_read_support_format_all(archive)
        archive_read_support_filter_all(archive)
        archive_read_open_filename(archive, lhaURL.path, 10240)
        
        var entry: OpaquePointer?
        archive_read_next_header(archive, &entry)
        
        let formatCode = archive_format(archive)
        let formatName = String(cString: archive_format_name(archive))
        
        print("Format code: \(formatCode) (hex: \(String(formatCode, radix: 16)))")
        print("Format name: \(formatName)")
    }
}
