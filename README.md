# SwiftArchive

A modern Swift library for working with archive files. Built on [libarchive](https://libarchive.org), SwiftArchive provides a clean, type-safe API for reading and writing archives in multiple formats.

## Features

- 📦 **Read**: ZIP, TAR, 7z, RAR, CPIO, ISO9660, CAB, XAR, LHA
- ✏️ **Write**: ZIP, TAR, 7z, CPIO
- 🗜️ **Compression**: Deflate, GZIP, BZIP2 (macOS)
- 🔒 **Encryption**: AES-256 for ZIP, read encrypted 7z/RAR
- 🧵 **Thread-safe** with Sendable types
- 📱 **Platforms**: macOS 15+, iOS 18+

## Installation

Add SwiftArchive to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/avdwerff/SwiftArchive.git", from: "x.y.z")
]
```

## Quick Start

```swift
import SwiftArchive

// Extract an archive
try Archive.extract(url: archiveURL, to: destinationURL)

// Create a ZIP archive
try Archive.create(from: sourceDirectory, to: archiveURL)

// Inspect an archive
let info = try Archive.info(url: archiveURL)
print("Format: \(info.format), Entries: \(info.entryCount)")

// List contents
let entries = try Archive.list(url: archiveURL)
for entry in entries {
    print("\(entry.path) - \(entry.size) bytes")
}
```

## Encryption

```swift
// Create encrypted ZIP with AES-256
try Archive.create(
    files: [fileURL],
    to: archiveURL,
    encryption: .aes256,
    password: "secret"
)

// Extract password-protected archive
try Archive.extract(url: archiveURL, to: destination, password: "secret")
```

## Compression Levels

```swift
// Create with maximum compression
try Archive.create(
    from: sourceDirectory,
    to: archiveURL,
    compression: .deflate,
    compressionLevel: 9
)
```

## Progress Tracking

```swift
try Archive.extract(url: archiveURL, to: destination) { progress in
    print("Progress: \(Int(progress * 100))%")
}
```

## Format Support

| Format | Read | Write | Encryption |
|--------|------|-------|------------|
| ZIP | ✅ | ✅ | AES-256, AES-128, ZipCrypto |
| TAR | ✅ | ✅ | — |
| 7z | ✅ | ✅ | Decrypt only |
| RAR | ✅ | — | Decrypt only |
| CPIO | ✅ | ✅ | — |
| ISO9660 | ✅ | — | — |
| CAB | ✅ | — | — |
| XAR | ✅ | — | — |
| LHA | ✅ | — | — |

## License

MIT
