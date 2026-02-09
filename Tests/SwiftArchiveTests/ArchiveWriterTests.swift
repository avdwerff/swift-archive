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
}
