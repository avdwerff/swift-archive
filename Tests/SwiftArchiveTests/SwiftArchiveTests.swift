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
        try Archive.create(files: [sourceDir], to: archiveURL) { _, progress in
            progressValues.append(progress)
        }

        #expect(progressValues.count >= 3)
        #expect(progressValues.last == 1.0)
        
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1])
        }
    }
    
    @Test func archiveCreateDirectoryProgressPerFile() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        for i in 0..<10 {
            let file = sourceDir.appendingPathComponent("file\(i).txt")
            try "Content \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        var progressCalls = 0
        var lastProgress: Double = 0
        
        try Archive.create(files: [sourceDir], to: archiveURL) { url, progress in
            progressCalls += 1
            #expect(progress >= lastProgress)
            lastProgress = progress
        }
        
        #expect(progressCalls >= 10)
        #expect(lastProgress == 1.0)
    }
    
    @Test func roundTripFilesIncludingDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let files = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        try Archive.create(files: [sourceDir], to: archiveURL)
        
        let entries = try Archive.list(url: archiveURL)
        print(">>> Entries: \(entries.map { $0.path })")
        
        try Archive.extract(url: archiveURL, to: extractDir)
        
        guard let file1Entry = entries.first(where: { $0.path.contains("file1.txt") }) else {
            Issue.record("file1.txt not found")
            return
        }
        
        let extractedPath = extractDir.appendingPathComponent(file1Entry.path)
        let content = try String(contentsOf: extractedPath, encoding: .utf8)
        #expect(content == "Hello, World!")
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
    
    // MARK: - ArchiveReader open Tests
    
    @Test func archiveReaderOpen() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader.open(url: zipURL)
        
        #expect(reader.url == zipURL)
    }
    
    // MARK: - ArchiveWriter Tests
    
    @Test func archiveWriterCreateFromDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        let writer = ArchiveWriter(url: archiveURL)
        try writer.addDirectory(at: sourceDir)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .zip)
    }
    
    @Test func archiveWriterAddFiles() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        
        let writer = ArchiveWriter(url: archiveURL)
        try writer.addFiles(files)
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let entries = try Archive.list(url: archiveURL)
        #expect(entries.count == 3)
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
        guard let extractedFile = findExtractedFile(named: "file1.txt", in: extractDir) else {
            Issue.record("file1.txt not found")
            return
        }
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
        
        guard let extractedFile = findExtractedFile(named: "file1.txt", in: extractDir) else {
            Issue.record("file1.txt not found")
            return
        }
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
            guard let extractedFile = findExtractedFile(named: "file\(i).bin", in: extractDir) else {
                Issue.record("file1.txt not found")
                return
            }
            let data = try Data(contentsOf: extractedFile)
            #expect(data.count == 100 * 1024)
        }
    }
    
    // MARK: - Encryption Tests
    
    @Test func archiveCreateEncrypted() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        
        try Archive.create(
            files: files,
            to: archiveURL,
            encryption: .aes256,
            password: "secret123"
        )
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        // Entries visible without password (ZIP behavior)
        let entries = try Archive.list(url: archiveURL)
        #expect(entries.count == 3)
        #expect(entries.first?.isEncrypted == true)
    }
    
    @Test func archiveExtractEncryptedWithPassword() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        try Archive.create(files: files, to: archiveURL, encryption: .aes256, password: "password")
        try Archive.extract(url: archiveURL, to: extractDir, password: "password")
        
        let content = try String(contentsOf: extractDir.appendingPathComponent("file1.txt"), encoding: .utf8)
        #expect(content == "Hello, World!")
    }
    
    @Test func archiveExtractEncryptedWrongPassword() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        try Archive.create(files: files, to: archiveURL, encryption: .aes256, password: "correct")
        
        #expect(throws: ArchiveError.self) {
            try Archive.extract(url: archiveURL, to: extractDir, password: "wrong")
        }
    }
    
    @Test func archiveExtractFileEncrypted() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        let password = "secret123"
        
        try Archive.create(files: files, to: archiveURL, encryption: .aes256, password: password)
        
        // Extract single file with password
        let data = try Archive.extractFile(from: archiveURL, path: "file1.txt", password: password)
        let content = String(data: data!, encoding: .utf8)
        
        #expect(content == "Hello, World!")
    }
    
    // MARK: - Compression Level Tests
    
    @Test func archiveCreateWithCompressionLevel() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("compressed.zip")
        
        try Archive.create(
            files: files,
            to: archiveURL,
            compression: .deflate,
            compressionLevel: 9
        )
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .zip)
    }
    
    @Test func archiveCreateFromDirectoryWithCompressionLevel() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("compressed.zip")
        
        try Archive.create(
            from: sourceDir,
            to: archiveURL,
            compression: .deflate,
            compressionLevel: 6
        )
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .zip)
    }
    
    @Test func archiveCompressionLevelAffectsSize() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create large compressible content
        let largeFile = tempDir.appendingPathComponent("large.txt")
        let content = String(repeating: "ABCDEFGHIJ", count: 50000)
        try content.write(to: largeFile, atomically: true, encoding: .utf8)
        
        let fastURL = tempDir.appendingPathComponent("fast.zip")
        let bestURL = tempDir.appendingPathComponent("best.zip")
        
        // Fast compression
        try Archive.create(
            files: [largeFile],
            to: fastURL,
            compression: .deflate,
            compressionLevel: 1
        )
        
        // Best compression
        try Archive.create(
            files: [largeFile],
            to: bestURL,
            compression: .deflate,
            compressionLevel: 9
        )
        
        let fastSize = try FileManager.default.attributesOfItem(atPath: fastURL.path)[.size] as! Int64
        let bestSize = try FileManager.default.attributesOfItem(atPath: bestURL.path)[.size] as! Int64
        
        // Best compression should be smaller or equal
        #expect(bestSize <= fastSize)
    }
    
    @Test func archiveCompressionLevelWithEncryption() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("compressed-encrypted.zip")
        let extractDir = tempDir.appendingPathComponent("extracted")
        let password = "secret123"
        
        try Archive.create(
            files: files,
            to: archiveURL,
            compression: .deflate,
            compressionLevel: 6,
            encryption: .aes256,
            password: password
        )
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        // Verify it's encrypted
        let entries = try Archive.list(url: archiveURL)
        #expect(entries.first?.isEncrypted == true)
        
        // Verify it extracts correctly
        try Archive.extract(url: archiveURL, to: extractDir, password: password)
        let content = try String(contentsOf: extractDir.appendingPathComponent("file1.txt"), encoding: .utf8)
        #expect(content == "Hello, World!")
    }
    
    @Test func archiveTarGzWithCompressionLevel() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        _ = try createTestFiles(in: sourceDir)
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        let extractDir = tempDir.appendingPathComponent("extracted")
        
        try Archive.create(
            from: sourceDir,
            to: archiveURL,
            format: .tar,
            compression: .gzip,
            compressionLevel: 9
        )
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .gzip)
        
        // Verify round-trip
        try Archive.extract(url: archiveURL, to: extractDir)
        
        // Find file1.txt in extracted contents
        let entries = try Archive.list(url: archiveURL)
        guard let entry = entries.first(where: { $0.path.contains("file1.txt") }) else {
            Issue.record("file1.txt not found in archive")
            return
        }
        
        let extractedPath = extractDir.appendingPathComponent(entry.path)
        let content = try String(contentsOf: extractedPath, encoding: .utf8)
        #expect(content == "Hello, World!")
    }
    
    @Test(.enabled(if: ArchiveCompression.bzip2.isAvailable))
    func archiveBzip2WithCompressionLevel() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let files = try createTestFiles(in: tempDir)
        let archiveURL = tempDir.appendingPathComponent("test.tar.bz2")
        
        try Archive.create(
            files: files,
            to: archiveURL,
            format: .tar,
            compression: .bzip2,
            compressionLevel: 9
        )
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .bzip2)
    }
    
    // MARK: - Helpers
    
    private func findExtractedFile(named fileName: String, in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(atPath: directory.path) else {
            return nil
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(fileName) {
                return directory.appendingPathComponent(file)
            }
        }
        return nil
    }
}
