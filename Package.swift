// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftArchive",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "SwiftArchive",
            targets: ["SwiftArchive"]
        ),
    ],
    targets: [
        .target(
            name: "CLibArchive",
            path: "Sources/CLibArchive",
            sources: ["libarchive"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("libarchive"),
                .headerSearchPath("include"),
                .define("HAVE_CONFIG_H"),
                .unsafeFlags(["-w"]),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2", .when(platforms: [.macOS])),
                .linkedLibrary("xml2"),
            ]
        ),
        .target(
            name: "SwiftArchive",
            dependencies: ["CLibArchive"]
        ),
        .testTarget(
            name: "SwiftArchiveTests",
            dependencies: ["SwiftArchive"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
