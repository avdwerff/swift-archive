//
//  XARFormatTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 23/03/2026.
//

import Testing
import Foundation
@testable import SwiftArchive

@Suite("XAR Format Tests")
struct XARFormatTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("XARFormatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Format Properties
    
    @Test("XAR format is readable")
    func xarFormatIsReadable() {
        #expect(ArchiveFormat.xar.canRead == true)
    }
    
    @Test("XAR format is not writable")
    func xarFormatIsNotWritable() {
        #expect(ArchiveFormat.xar.canWrite == false)
    }

    @Test("XAR format is in supported read formats")
    func xarInSupportedFormats() {
        // XAR should be readable
        #expect(ArchiveFormat.xar.canRead == true)
    }
    
    // MARK: - Format Detection
    
    @Test("Detect XAR format from file")
    func detectXARFormat() throws {
        let xarURL = fixtureURL("test.xar")
        let (format, _) = try Archive.detectFormat(url: xarURL)
        
        #expect(format == .xar)
    }
    
    @Test("XAR file is recognized as archive")
    func xarIsArchive() throws {
        let xarURL = fixtureURL("test.xar")
        
        #expect(Archive.isArchive(url: xarURL) == true)
    }
    
    // MARK: - Archive Info
    
    @Test("Get XAR archive info")
    func xarArchiveInfo() throws {
        let xarURL = fixtureURL("test.xar")
        let info = try Archive.info(url: xarURL)
        
        #expect(info.format == .xar)
        #expect(info.entryCount > 0)
    }
    
    // MARK: - Listing Contents
    
    @Test("List XAR archive contents")
    func xarListContents() throws {
        let xarURL = fixtureURL("test.xar")
        let entries = try Archive.list(url: xarURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test("XAR archive contains files")
    func xarContainsFiles() throws {
        let xarURL = fixtureURL("test.xar")
        let entries = try Archive.list(url: xarURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Extraction
    
    @Test("Extract XAR archive")
    func xarExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let xarURL = fixtureURL("test.xar")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: xarURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract XAR archive with progress")
    func xarExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let xarURL = fixtureURL("test.xar")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: xarURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
        
        // Progress should be monotonically increasing
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
    }
    
    @Test("Extract XAR with overwrite")
    func xarExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let xarURL = fixtureURL("test.xar")
        let outputDir = tempDir.appendingPathComponent("output")
        
        // Extract twice with overwrite
        try Archive.extract(url: xarURL, to: outputDir)
        try Archive.extract(url: xarURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test("Extract XAR fails without overwrite")
    func xarExtractFailsWithoutOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let xarURL = fixtureURL("test.xar")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: xarURL, to: outputDir)
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: xarURL, to: outputDir, overwrite: false)
        }
    }
    
    // MARK: - Single File Extraction
    
    @Test("Extract single file from XAR")
    func xarExtractSingleFile() throws {
        let xarURL = fixtureURL("test.xar")
        let entries = try Archive.list(url: xarURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.xar")
            return
        }
        
        let data = try Archive.extractFile(from: xarURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    @Test("Extract nonexistent file from XAR returns nil")
    func xarExtractNonexistentFile() throws {
        let xarURL = fixtureURL("test.xar")
        let data = try Archive.extractFile(from: xarURL, path: "nonexistent.txt")
        
        #expect(data == nil)
    }
    
    // MARK: - ArchiveReader Tests
    
    @Test("Open XAR with ArchiveReader")
    func xarArchiveReaderOpen() throws {
        let xarURL = fixtureURL("test.xar")
        let reader = try ArchiveReader.open(url: xarURL)
        
        #expect(reader.url == xarURL)
    }
    
    // MARK: - Concurrent Access
    
    @Test("Concurrent XAR reads")
    func xarConcurrentReads() async throws {
        let xarURL = fixtureURL("test.xar")
        
        async let info1 = Task.detached { try Archive.info(url: xarURL) }.value
        async let info2 = Task.detached { try Archive.info(url: xarURL) }.value
        async let info3 = Task.detached { try Archive.info(url: xarURL) }.value
        
        let results = try await [info1, info2, info3]
        
        #expect(results.allSatisfy { $0.format == .xar })
    }
}
