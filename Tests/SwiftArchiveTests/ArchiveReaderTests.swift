import Testing
import Foundation
@testable import SwiftArchive

@Suite("ArchiveReader Tests")
struct ArchiveReaderTests {
    
    private func fixtureURL(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
    }
    
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftArchiveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    // MARK: - Initialization Tests
    
    @Test func initWithValidURL() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        
        #expect(reader.url == zipURL)
    }
    
    @Test func initWithInvalidURL() throws {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/file.zip")
        
        #expect(throws: ArchiveError.self) {
            _ = try ArchiveReader(url: nonExistentURL)
        }
    }
    
    @Test func initWithPassword() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL, password: "secret")
        
        #expect(reader.url == zipURL)
    }
    
    // MARK: - Info Tests
    
    @Test func infoReturnsCorrectEntryCount() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let info = try reader.info()
        
        #expect(info.entryCount > 0)
    }
    
    @Test func infoDetectsZipFormat() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let info = try reader.info()
        
        #expect(info.format == .zip)
    }
    
    @Test func infoCalculatesUncompressedSize() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let info = try reader.info()
        
        #expect(info.uncompressedSize > 0)
    }
    
    @Test func infoCalculatesCompressedSize() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let info = try reader.info()
        
        #expect(info.compressedSize > 0)
    }
    
    // MARK: - List Entries Tests
    
    @Test func listEntriesReturnsAllEntries() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let entries = try reader.listEntries()
        
        #expect(!entries.isEmpty)
    }
    
    @Test func listEntriesIncludesFileMetadata() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        let entries = try reader.listEntries()
        
        let files = entries.filter { $0.type == .file }
        #expect(!files.isEmpty)
        
        for file in files {
            #expect(file.size >= 0)
            #expect(!file.path.isEmpty)
        }
    }
    
    // MARK: - ForEachEntry Tests
    
    @Test func forEachEntryIteratesAllEntries() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        
        var count = 0
        try reader.forEachEntry { _ in
            count += 1
        }
        
        let entries = try ArchiveReader(url: zipURL).listEntries()
        #expect(count == entries.count)
    }
    
    // MARK: - Extract Single File Tests
    
    @Test func extractReturnsFileData() throws {
        let zipURL = fixtureURL("test2.zip")
        let reader = try ArchiveReader(url: zipURL)
        let entries = try reader.listEntries()
        
        guard let fileEntry = entries.first(where: { $0.type == .file }) else {
            Issue.record("No file entries in test.zip")
            return
        }
        
        let reader2 = try ArchiveReader(url: zipURL)
        let data = try reader2.extract(path: fileEntry.path)
        
        #expect(data != nil)
        #expect(data!.count > 0)
    }
    
    // MARK: - Reusability Tests
    
    @Test func readerIsReusable() throws {
        let zipURL = fixtureURL("test.zip")
        let reader = try ArchiveReader(url: zipURL)
        
        _ = try reader.info()
        _ = try reader.listEntries()
        _ = try reader.info()
        
        #expect(true) // If we get here without error, reader is reusable
    }

}
