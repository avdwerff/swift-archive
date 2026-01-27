# SwiftArchive

A modern Swift library for working with archive files. Built on [libarchive](https://libarchive.org), 
SwiftArchive provides a clean, type-safe API for reading and writing archives in multiple formats.

## Features

- 📦 **Read**: ZIP, TAR, 7z, RAR, CPIO, ISO9660, CAB, XAR
- ✏️ **Write**: ZIP, TAR, 7z, CPIO, XAR
- 🗜️ **Compression**: GZIP, BZIP2, XZ, ZSTD, LZ4, LZMA
- 🔒 **Password-protected** archive support
- 🧵 **Thread-safe** with Sendable types
- 📱 **Apple platforms**: macOS, iOS, tvOS, watchOS, visionOS

## Quick Start
```swift
// Extract
try Archive.extract(url: archiveURL, to: destinationURL)

// Create
try Archive.create(from: sourceDirectory, to: archiveURL)

// Inspect
let info = try Archive.info(url: archiveURL)
print("Format: \(info.format), Entries: \(info.entryCount)")
```
