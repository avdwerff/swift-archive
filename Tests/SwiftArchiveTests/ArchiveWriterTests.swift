//
//  ArchiveWriterTests.swift
//  SwiftArchive
//
//  Created by Alexander van der Werff on 11/01/2026.
//

import Testing
import Foundation
@testable import SwiftArchive

@Suite("ArchiveWriter Tests")
struct ArchiveWriterTests {
    
    // MARK: - Test Helpers
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftArchiveWriterTests-\(UUID().uuidString)")
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
    
    // MARK: - Initialization Tests
    
    @Test func initWithDefaults() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)
        
        #expect(writer.url == archiveURL)
        #expect(writer.format == .zip)
        #expect(writer.compression == .none)
    }
    
    @Test func initWithFormat() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar")
        let writer = ArchiveWriter(url: archiveURL, format: .tar)
        
        #expect(writer.format == .tar)
    }
    
    @Test func initWithCompression() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        let writer = ArchiveWriter(url: archiveURL, format: .tar, compression: .gzip)
        
        #expect(writer.format == .tar)
        #expect(writer.compression == .gzip)
    }
    
    // MARK: - Write Builder Tests
    
    @Test func writeCreatesArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
            try context.addFile(path: "test2.txt", data: "Hello".data(using: .utf8)!)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
    
    // MARK: - Sendable Tests
    
    @Test func writerIsSendable() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)
        
        try await Task.detached {
            try writer.write { context in
                try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
            }
        }.value
        
        let reader = try ArchiveReader(url: archiveURL)
        let entries = try reader.listEntries()
        #expect(entries.count == 1)
    }
    
    @Test func concurrentWrites() async throws {
        let tempDir = try createTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let writer1 = ArchiveWriter(url: tempDir.appendingPathComponent("test1.zip"))
        let writer2 = ArchiveWriter(url: tempDir.appendingPathComponent("test2.zip"))
        let writer3 = ArchiveWriter(url: tempDir.appendingPathComponent("test3.zip"))
        
        // Write concurrently from different tasks
        async let r1: () = Task.detached {
            try writer1.write { ctx in
                try ctx.addFile(path: "file.txt", data: "Content 1".data(using: .utf8)!)
            }
        }.value
        
        async let r2: () = Task.detached {
            try writer2.write { ctx in
                try ctx.addFile(path: "file.txt", data: "Content 2".data(using: .utf8)!)
            }
        }.value
        
        async let r3: () = Task.detached {
            try writer3.write { ctx in
                try ctx.addFile(path: "file.txt", data: "Content 3".data(using: .utf8)!)
            }
        }.value
        
        _ = try await (r1, r2, r3)
        
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("test1.zip").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("test2.zip").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("test3.zip").path))
    }
    
    // MARK: - Format Tests
    
    @Test func createTarArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar")
        let writer = ArchiveWriter(url: archiveURL, format: .tar)
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
        }
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
    }
    
    @Test func createTarGzArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        let writer = ArchiveWriter(url: archiveURL, format: .tar, compression: .gzip)
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
        }
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .gzip)
    }
    
    // MARK: - Encryption Tests

    @Test func createEncryptedZipArchive() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            encryption: .aes256,
            password: "secret123"
        )
        
        try writer.write { context in
            try context.addFile(path: "secret.txt", data: "Top secret content".data(using: .utf8)!)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        // List entries works without password (headers are not encrypted)
        let readerNoPassword = try ArchiveReader(url: archiveURL)
        let entries = try readerNoPassword.listEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.isEncrypted == true)  // Entry should report as encrypted
        
        // Extract FAILS with wrong password
        let readerWrongPassword = try ArchiveReader(url: archiveURL, password: "wrongpassword")
        #expect(throws: ArchiveError.self) {
            _ = try readerWrongPassword.extract(path: "secret.txt")
        }
        
        // Extract SUCCEEDS with correct password
        let readerCorrectPassword = try ArchiveReader(url: archiveURL, password: "secret123")
        let data = try readerCorrectPassword.extract(path: "secret.txt")
        #expect(String(data: data!, encoding: .utf8) == "Top secret content")
    }
    
    @Test func readEncryptedArchiveWithWrongPassword() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("encrypted.zip")
        
        // Create encrypted archive
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            encryption: .aes256,
            password: "correctpassword"
        )
        
        try writer.write { context in
            try context.addFile(path: "secret.txt", data: "Secret".data(using: .utf8)!)
        }
        
        // Try to read with wrong password
        let reader = try ArchiveReader(url: archiveURL, password: "wrongpassword")
        
        #expect(throws: ArchiveError.self) {
            _ = try reader.extract(path: "secret.txt")
        }
    }
    
    // MARK: - Different Encryption Methods
    
    @Test func createZipWithAES128() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("aes128.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            encryption: .aes128,
            password: "secret"
        )
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
        }
        
        let reader = try ArchiveReader(url: archiveURL, password: "secret")
        let data = try reader.extract(path: "test.txt")
        #expect(String(data: data!, encoding: .utf8) == "Hello")
    }
    
    // MARK: - addFile with Directory Tests

    @Test func addFileWithDirectoryURLAddsContentsRecursively() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a directory structure to add via addFile(at:)
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let file1 = sourceDir.appendingPathComponent("hello.txt")
        let subdir = sourceDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let file2 = subdir.appendingPathComponent("deep.txt")

        try "Hello from root".write(to: file1, atomically: true, encoding: .utf8)
        try "Hello from nested".write(to: file2, atomically: true, encoding: .utf8)

        // Pass the directory URL to addFile(at:) — it should detect it's a directory
        // and delegate to addDirectory(at:basePath:)
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)

        try writer.write { context in
            try context.addFile(at: sourceDir)
        }

        // Verify the archive contains the directory entries and files
        let reader = try ArchiveReader(url: archiveURL)
        let entries = try reader.listEntries()
        let paths = entries.map(\.path)

        #expect(paths.contains(where: { $0.contains("hello.txt") }), "Archive should contain hello.txt")
        #expect(paths.contains(where: { $0.contains("deep.txt") }), "Archive should contain nested/deep.txt")
    }

    @Test func addFileWithDirectoryURLRespectsArchivePath() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a simple directory with one file
        let sourceDir = tempDir.appendingPathComponent("mydir")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let file = sourceDir.appendingPathComponent("data.txt")
        try "Some data".write(to: file, atomically: true, encoding: .utf8)

        // Pass a custom archivePath (basePath) when adding the directory
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)

        try writer.write { context in
            try context.addFile(at: sourceDir, archivePath: "custom-root")
        }

        let reader = try ArchiveReader(url: archiveURL)
        let entries = try reader.listEntries()
        let paths = entries.map(\.path)

        // The entries should be under "custom-root/" not "mydir/"
        #expect(paths.contains(where: { $0.hasPrefix("custom-root/") }), "Archive entries should use the custom archivePath as base, got: \(paths)")
        #expect(!paths.contains(where: { $0.hasPrefix("mydir/") }), "Archive entries should not use the original directory name, got: \(paths)")
    }

    @Test func addFileWithRegularFileStillWorks() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Ensure that addFile(at:) still works correctly for regular files
        let fileURL = tempDir.appendingPathComponent("regular.txt")
        try "Regular file content".write(to: fileURL, atomically: true, encoding: .utf8)

        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(url: archiveURL)

        try writer.write { context in
            try context.addFile(at: fileURL)
        }

        let reader = try ArchiveReader(url: archiveURL)
        let entries = try reader.listEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.path == "regular.txt")

        // Verify content round-trips correctly
        let extracted = try reader.extract(path: "regular.txt")
        #expect(String(data: extracted!, encoding: .utf8) == "Regular file content")
    }

    // MARK: - Compression Level Tests
    
    @Test func initWithCompressionLevel() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 9
        )
        
        #expect(writer.compression == .deflate)
        #expect(writer.compressionLevel == 9)
    }
    
    @Test func compressionLevelFastestZip() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("fast.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 1
        )
        
        // Create large compressible data
        let data = String(repeating: "Hello World! ", count: 10000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .zip)
    }
    
    @Test func compressionLevelBestZip() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("best.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 9
        )
        
        let data = String(repeating: "Hello World! ", count: 10000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
    
    @Test func compressionLevelAffectsFileSize() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create large compressible data
        let data = String(repeating: "ABCDEFGHIJ", count: 50000).data(using: .utf8)!
        
        // Fast compression (level 1)
        let fastURL = tempDir.appendingPathComponent("fast.zip")
        let fastWriter = ArchiveWriter(
            url: fastURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 1
        )
        try fastWriter.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        // Best compression (level 9)
        let bestURL = tempDir.appendingPathComponent("best.zip")
        let bestWriter = ArchiveWriter(
            url: bestURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 9
        )
        try bestWriter.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        let fastSize = try FileManager.default.attributesOfItem(atPath: fastURL.path)[.size] as! Int64
        let bestSize = try FileManager.default.attributesOfItem(atPath: bestURL.path)[.size] as! Int64
        
        // Best compression should produce smaller or equal file
        #expect(bestSize <= fastSize)
    }
    
    @Test func compressionLevelTarGz() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.gz")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .tar,
            compression: .gzip,
            compressionLevel: 6
        )
        
        let data = String(repeating: "Test data ", count: 1000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .gzip)
    }
    
    @Test(.enabled(if: ArchiveCompression.bzip2.isAvailable))
    func compressionLevelBzip2() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.tar.bz2")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .tar,
            compression: .bzip2,
            compressionLevel: 9
        )
        
        let data = String(repeating: "Bzip2 test ", count: 1000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .tar)
        #expect(info.compression == .bzip2)
    }
    
    @Test func compressionLevelSevenZip() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("test.7z")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .sevenZip,
            compressionLevel: 9
        )
        
        let data = String(repeating: "7zip test ", count: 1000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: data)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        
        let info = try Archive.info(url: archiveURL)
        #expect(info.format == .sevenZip)
    }
    
    @Test func compressionLevelWithEncryption() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("encrypted-compressed.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 6,
            encryption: .aes256,
            password: "secret123"
        )
        
        let data = String(repeating: "Secret data ", count: 1000).data(using: .utf8)!
        
        try writer.write { context in
            try context.addFile(path: "secret.txt", data: data)
        }
        
        // Verify it's readable with password
        let reader = try ArchiveReader(url: archiveURL, password: "secret123")
        let extracted = try reader.extract(path: "secret.txt")
        #expect(extracted == data)
    }
    
    @Test func compressionLevelProducesDifferentSizes() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Use data with enough redundancy that compression level matters,
        // but not so uniform that every level compresses identically.
        // Mix repeated patterns with varying content to create realistic compressible data.
        var content = ""
        for i in 0..<5000 {
            content += "The quick brown fox jumps over the lazy dog \(i % 100) "
        }
        let data = content.data(using: .utf8)!

        // Create archives at levels 1 and 9
        let level1URL = tempDir.appendingPathComponent("level1.zip")
        let level9URL = tempDir.appendingPathComponent("level9.zip")

        let writer1 = ArchiveWriter(
            url: level1URL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 1
        )
        try writer1.write { context in
            try context.addFile(path: "data.txt", data: data)
        }

        let writer9 = ArchiveWriter(
            url: level9URL,
            format: .zip,
            compression: .deflate,
            compressionLevel: 9
        )
        try writer9.write { context in
            try context.addFile(path: "data.txt", data: data)
        }

        let size1 = try FileManager.default.attributesOfItem(atPath: level1URL.path)[.size] as! Int64
        let size9 = try FileManager.default.attributesOfItem(atPath: level9URL.path)[.size] as! Int64

        print(size1)
        print(size9)
        #expect(size9 < size1, "Level 9 (\(size9) bytes) should be strictly smaller than level 1 (\(size1) bytes). If equal, compression level is not being applied.")
    }

    @Test func compressionLevelNilUsesDefault() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let archiveURL = tempDir.appendingPathComponent("default.zip")
        let writer = ArchiveWriter(
            url: archiveURL,
            format: .zip,
            compression: .deflate,
            compressionLevel: nil  // No level specified
        )
        
        #expect(writer.compressionLevel == nil)
        
        try writer.write { context in
            try context.addFile(path: "test.txt", data: "Hello".data(using: .utf8)!)
        }
        
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }
}
