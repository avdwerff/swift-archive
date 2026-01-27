//
//  SwiftArchiveTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 11/01/2026.
//

import Testing
import Foundation
@testable import SwiftArchive

struct SwiftArchiveTests {
    
    // MARK: - Test Helpers
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftArchiveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func createTestFiles(in directory: URL) throws -> [URL] {
        let file1 = directory.appendingPathComponent("file1.txt")
        let file2 = directory.appendingPathComponent("file2.txt")
        let subdir = directory.appendingPathComponent("subdir")
        let nested = subdir.appendingPathComponent("nested.txt")
        
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        
        try "Hello, World!".write(to: file1, atomically: true, encoding: .utf8)
        try "Second file content".write(to: file2, atomically: true, encoding: .utf8)
        try "Nested file content".write(to: nested, atomically: true, encoding: .utf8)
        
        return [file1, file2, nested]
    }
    
    // MARK: - Archive.info Tests
    
    @Test func archiveInfo() throws {
        let zipURL = fixtureURL("test.zip")
        let info = try Archive.info(url: zipURL)
        
        #expect(info.format == .zip)
        #expect(info.entryCount > 0)
        #expect(info.compressedSize > 0)
    }
    
    @Test func archiveInfoWithPassword() throws {
        let zipURL = fixtureURL("test.zip")
        let info = try Archive.info(url: zipURL, password: "unused")
        
        #expect(info.format == .zip)
    }
    
    @Test func archiveInfoInvalidURL() throws {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.zip")
        
        #expect(throws: ArchiveError.self) {
            _ = try Archive.info(url: invalidURL)
        }
    }
    
    // MARK: - Archive.list Tests
    
    @Test func archiveList() throws {
        let zipURL = fixtureURL("test.zip")
        let entries = try Archive.list(url: zipURL)
        
        #expect(!entries.isEmpty)
    }
    
    @Test func archiveListContainsFiles() throws {
        let zipURL = fixtureURL("test.zip")
        let entries = try Archive.list(url: zipURL)
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
    }
    
    // MARK: - Archive.extract Tests
    
    @Test func archiveExtract() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipURL = fixtureURL("test.zip")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: zipURL, to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test func archiveExtractWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipURL = fixtureURL("test.zip")
        let outputDir = tempDir.appendingPathComponent("output")
        
        var progressValues: [Double] = []
        try Archive.extract(url: zipURL, to: outputDir) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
    }
    
    @Test func archiveExtractWithOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipURL = fixtureURL("test.zip")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: zipURL, to: outputDir)
        try Archive.extract(url: zipURL, to: outputDir, overwrite: true)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test func archiveExtractFailsWithoutOverwrite() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipURL = fixtureURL("test.zip")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try Archive.extract(url: zipURL, to: outputDir)
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: zipURL, to: outputDir, overwrite: false)
        }
    }
    
    // MARK: - Archive.extractFile Tests
    
    @Test func archiveExtractFile() throws {
        let zipURL = fixtureURL("test.zip")
        let entries = try Archive.list(url: zipURL)
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.zip")
            return
        }
        
        let data = try Archive.extractFile(from: zipURL, path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    @Test func archiveExtractFileNotFound() throws {
        let zipURL = fixtureURL("test.zip")
        let data = try Archive.extractFile(from: zipURL, path: "nonexistent.txt")
        
        #expect(data == nil)
    }
    
    // MARK: - Archive.create Tests
    
    @Test func archiveCreateFromDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        try Archive.create(from: sourceDir, to: archiveURL)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .zip)
        #expect(info.entryCount >= 3)
    }
    
    @Test func archiveCreateFromFiles() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        try Archive.create(files: files, to: archiveURL)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let entries = try Archive.list(url: archiveURL)
        #expect(entries.count == 3)
    }
    
    @Test func archiveCreateWithFormat() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        
        try Archive.create(from: sourceDir, to: archiveURL, format: .tar, compression: .gzip)
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .gzip)
    }
    
    @Test func archiveCreateWithProgress() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        var progressValues: [Double] = []
        try Archive.create(from: sourceDir, to: archiveURL) { progress in
            progressValues.append(progress)
        }
        
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
    }
    
    // MARK: - Archive.detectFormat Tests
    
    @Test func archiveDetectFormat() throws {
        let zipURL = fixtureURL("test.zip")
        let (format, _) = try Archive.detectFormat(url: zipURL)
        
        #expect(format == .zip)
    }
    
    // MARK: - Archive.isArchive Tests
    
    @Test func archiveIsArchiveTrue() throws {
        let zipURL = fixtureURL("test.zip")
        
        #expect(Archive.isArchive(url: zipURL) == true)
    }
    
    @Test func archiveIsArchiveFalse() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let textFile = tempDir.appendingPathComponent("text.txt")
        try "Not an archive".write(to: textFile, atomically: true, encoding: .utf8)
        
        #expect(Archive.isArchive(url: textFile) == false)
    }
    
    @Test func archiveIsArchiveNonexistent() throws {
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/file.zip")
        
        #expect(Archive.isArchive(url: nonexistentURL) == false)
    }
    
    // MARK: - URL Extension Tests
    
    @Test func urlIsArchive() throws {
        let zipURL = fixtureURL("test.zip")
        
        #expect(zipURL.isArchive == true)
    }
    
    @Test func urlArchiveInfo() throws {
        let zipURL = fixtureURL("test.zip")
        let info = try zipURL.archiveInfo()
        
        #expect(info.format == .zip)
    }
    
    @Test func urlArchiveEntries() throws {
        let zipURL = fixtureURL("test.zip")
        let entries = try zipURL.archiveEntries()
        
        #expect(!entries.isEmpty)
    }
    
    @Test func urlExtractArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let zipURL = fixtureURL("test.zip")
        let outputDir = tempDir.appendingPathComponent("output")
        
        try zipURL.extractArchive(to: outputDir)
        
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
        #expect(!contents.isEmpty)
    }
    
    @Test func urlCreateArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        try sourceDir.createArchive(at: archiveURL)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
    
    // MARK: - ArchiveReader open Tests
    
    @Test func archiveReaderOpen() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader.open(url: zipURL)
        
        #expect(reader.url == zipURL)
    }
    
    // MARK: - ArchiveWriter archive Tests
    
    @Test func archiveWriterArchiveDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        try ArchiveWriter.archive(directory: sourceDir, to: archiveURL)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
    
    @Test func archiveWriterArchiveFiles() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        try ArchiveWriter.archive(files: files, to: archiveURL)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
    
    // MARK: - Round-trip Tests
    
    @Test func roundTripDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create source
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        // Create archive
        try Archive.create(from: sourceDir, to: archiveURL)
        
        // Extract archive
        try Archive.extract(url: archiveURL, to: extractDir)
        
        // Verify content
        let extractedFile = extractDir.appendingPathComponent("source/file1.txt")
        let content = try String(contentsOf: extractedFile, encoding: .utf8)
        
        #expect(content == "Hello, World!")
    }
    
    @Test func roundTripFiles() throws {
        let tempDir = try createTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create source files
        let files = try createTestFiles(in: tempDir)
        let originalContent = try String(contentsOf: files[0], encoding: .utf8)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        // Create and extract
        try Archive.create(files: files, to: archiveURL)
        try Archive.extract(url: archiveURL, to: extractDir)
        
        // Verify
        let extractedFile = extractDir.appendingPathComponent("file1.txt")
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        
        #expect(extractedContent == originalContent)
    }
    
    @Test func roundTripTarGz() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        // Create tar.gz
        try Archive.create(from: sourceDir, to: archiveURL, format: .tar, compression: .gzip)
        
        // Verify format
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .gzip)
        
        // Extract and verify content
        try Archive.extract(url: archiveURL, to: extractDir)
        
        let extractedFile = extractDir.appendingPathComponent("source/file1.txt")
        let content = try String(contentsOf: extractedFile, encoding: .utf8)
        
        #expect(content == "Hello, World!")
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test func concurrentReads() async throws {
        let zipURL = fixtureURL("test.zip")
        
        async let info1 = Task.detached { try Archive.info(url: zipURL) }.value
        async let info2 = Task.detached { try Archive.info(url: zipURL) }.value
        async let info3 = Task.detached { try Archive.info(url: zipURL) }.value
        
        let results = try await [info1, info2, info3]
        
        #expect(results.allSatisfy { $0.format == .zip })
    }
    
    @Test func concurrentWrites() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archive1 = tempDir.appendingPathComponent("test1.zip")
        let archive2 = tempDir.appendingPathComponent("test2.zip")
        let archive3 = tempDir.appendingPathComponent("test3.zip")
        
        async let r1: () = Task.detached {
            try Archive.create(from: sourceDir, to: archive1)
        }.value
        
        async let r2: () = Task.detached {
            try Archive.create(from: sourceDir, to: archive2)
        }.value
        
        async let r3: () = Task.detached {
            try Archive.create(from: sourceDir, to: archive3)
        }.value
        
        _ = try await (r1, r2, r3)
        
        #expect(FileManager.default.fileExists(atPath: archive1.path))
        #expect(FileManager.default.fileExists(atPath: archive2.path))
        #expect(FileManager.default.fileExists(atPath: archive3.path))
    }
    
    // MARK: - Large Archive Tests
    
    @Test func largeArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create 10 files of 100KB each
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        for i in 0..<10 {
            let data = Data(repeating: UInt8(i), count: 100 * 1024)
            let fileURL = sourceDir.appendingPathComponent("file\(i).bin")
            try data.write(to: fileURL)
        }
        
        let archiveURL = tempDir.appendingPathComponent("large.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        // Create
        try Archive.create(from: sourceDir, to: archiveURL)
        
        // Verify
        let info = try Archive.info(url: archiveURL)
        #expect(info.entryCount == 10)
        
        // Extract
        try Archive.extract(url: archiveURL, to: extractDir)
        
        // Verify extracted files
        for i in 0..<10 {
            let extractedFile = extractDir.appendingPathComponent("source/file\(i).bin")
            let data = try Data(contentsOf: extractedFile)
            #expect(data.count == 100 * 1024)
        }
    }
}
