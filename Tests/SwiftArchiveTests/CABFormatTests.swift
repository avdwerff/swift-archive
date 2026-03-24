//
//  CABFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 24/03/2026.
//

import Testing
import Foundation
import CLibArchive
@testable import SwiftArchive

@Suite("CAB Format Tests")
struct CABFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CABFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("CAB format is readable")
    func cabFormatIsReadable() {
        #expect(ArchiveFormat.cab.canRead == true)
    }
    
    @Test("CAB format is not writable")
    func cabFormatIsNotWritable() {
        #expect(ArchiveFormat.cab.canWrite == false)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect CAB format from file")
    func detectCABFormat() throws {
        let cabURL = fixtureURL("test.cab")
        let (format, _) = try Archive.detectFormat(url: cabURL)
        
        #expect(format == .cab)
    }
    
    @Test("CAB file is recognized as archive")
    func cabIsArchive() throws {
        let cabURL = fixtureURL("test.cab")
        
        #expect(Archive.isArchive(url: cabURL) == true)
    }
    
    // MARK: - Archive Info
    @Test("Debug: CAB format code")
    func debugCABFormatCode() throws {
        let cabURL = fixtureURL("test.cab")
        
        let archive = archive_read_new()
        defer { archive_read_free(archive) }
        
        archive_read_support_format_all(archive)
        archive_read_support_filter_all(archive)
        archive_read_open_filename(archive, cabURL.path, 10240)
        
        var entry: OpaquePointer?
        archive_read_next_header(archive, &entry)
        
        let formatCode = archive_format(archive)
        let formatName = String(cString: archive_format_name(archive))
        
        print("Format code: \(formatCode) (hex: \(String(formatCode, radix: 16)))")
        print("Format name: \(formatName)")
    }
    @Test("Get CAB archive info")
    func cabArchiveInfo() throws {
        let cabURL = fixtureURL("test.cab")
        let info = try Archive.info(url: cabURL)
        
        #expect(info.format == .cab)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List CAB archive contents")
    func cabListContents() throws {
        let cabURL = fixtureURL("test.cab")
        let entries = try Archive.list(url: cabURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test("CAB archive contains files")
    func cabContainsFiles() throws {
        let cabURL = fixtureURL("test.cab")
        let entries = try Archive.list(url: cabURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Extraction
    
    @Test("Extract CAB archive")
    func cabExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cabURL = fixtureURL("test.cab")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: cabURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract CAB archive with progress")
    func cabExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cabURL = fixtureURL("test.cab")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: cabURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
        
        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
    }
    
    @Test("Extract CAB with overwrite")
    func cabExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cabURL = fixtureURL("test.cab")
        let outputDir = tempDir.appendingPathComponent("output")
        
        // Extract twice with overwrite
        try Archive.extract(url: cabURL, to: outputDir)
        try Archive.extract(url: cabURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract CAB fails without overwrite")
    func cabExtractFailsWithoutOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cabURL = fixtureURL("test.cab")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: cabURL, to: outputDir)
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: cabURL, to: outputDir, overwrite: false)
        }
    }
    
    // MARK: - Single File Extraction
    
    @Test("Extract single file from CAB")
    func cabExtractSingleFile() throws {
        let cabURL = fixtureURL("test.cab")
        let entries = try Archive.list(url: cabURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.cab")
            return
        }
        
        let data = try Archive.extractFile(from: cabURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    @Test("Extract nonexistent file from CAB returns nil")
    func cabExtractNonexistentFile() throws {
        let cabURL = fixtureURL("test.cab")
        let data = try Archive.extractFile(from: cabURL, path: "nonexistent.txt")
        
        #expect(data == nil)
    }
    
    // MARK: - ArchiveReader Tests
    
    @Test("Open CAB with ArchiveReader")
    func cabArchiveReaderOpen() throws {
        let cabURL = fixtureURL("test.cab")
        let reader = try ArchiveReader.open(url: cabURL)
        
        #expect(reader.url == cabURL)
    }
    
    // MARK: - Concurrent Access
    
    @Test("Concurrent CAB reads")
    func cabConcurrentReads() async throws {
        let cabURL = fixtureURL("test.cab")
        
        async let info1 = Task.detached { try Archive.info(url: cabURL) }.value
        async let info2 = Task.detached { try Archive.info(url: cabURL) }.value
        async let info3 = Task.detached { try Archive.info(url: cabURL) }.value
        
        let results = try await [info1, info2, info3]
        
        #expect(results.allSatisfy { $0.format == .cab })
    }
}
