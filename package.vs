// The 'compress' repository: standard data compression formats for Vertex.
import PackageDescription

let package = Package(
    name: "compress",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "compress/flate", targets: ["flate"]),
        .library(name: "compress/zlib", targets: ["zlib"]),
        .library(name: "compress/gzip", targets: ["gzip"]),
        .library(name: "compress/lz4", targets: ["lz4"]),
        .executable(name: "check", targets: ["check"]),
    ],
    targets: [
        // flate: RFC 1951 raw DEFLATE compression and decompression.
        .target(
            name: "flate",
            path: "flate"
        ),
        // zlib: RFC 1950 zlib stream format (CMF/FLG + DEFLATE + Adler-32).
        .target(
            name: "zlib",
            dependencies: ["flate"],
            path: "zlib"
        ),
        // gzip: RFC 1952 gzip file format (10-byte header + DEFLATE + CRC32 trailer).
        .target(
            name: "gzip",
            dependencies: ["flate"],
            path: "gzip"
        ),
        // lz4: High-speed byte-level LZ4 block compression.
        .target(
            name: "lz4",
            path: "lz4"
        ),
        // Comprehensive test suite.
        .executableTarget(
            name: "check",
            dependencies: ["flate", "zlib", "gzip", "lz4"],
            path: "tests/check"
        ),
    ]
)
