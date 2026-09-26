# compress

[![package: vs-package](https://img.shields.io/badge/package-vs--package-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language)
[![formats: flate | zlib | gzip | lz4](https://img.shields.io/badge/formats-flate%20%7C%20zlib%20%7C%20gzip%20%7C%20lz4-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language/compress)
[![status: tested](https://img.shields.io/badge/status-tested-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language/compress)

Standard compression formats: encoders and decoders for raw DEFLATE (RFC 1951), zlib (RFC 1950), gzip (RFC 1952), and high-speed LZ4 block compression, composing natively with `io` streaming protocols.

> **Status.** Implementations of `compress/flate`, `compress/zlib`,
> `compress/gzip`, and `compress/lz4` with zero external dependencies. The full
> test suite in `cmd/check` passes, covering round-trip verification,
> streaming `io.Reader`/`io.Writer` adapters, checksum validation, and edge cases.

---

## Packages

| Package | Import Path | Specification | Typical Use Cases |
| --- | --- | --- | --- |
| **`flate`** | `import "compress/flate"` | RFC 1951 (raw DEFLATE) | ZIP archives, custom container formats, foundation for zlib & gzip |
| **`zlib`** | `import "compress/zlib"` | RFC 1950 (CMF/FLG + Adler-32) | PNG image IDAT chunks, Git object loose storage, PDF streams |
| **`gzip`** | `import "compress/gzip"` | RFC 1952 (10-byte header + CRC32) | HTTP Content-Encoding, `.tar.gz` pipelines, web assets |
| **`lz4`** | `import "compress/lz4"` | LZ4 Block Format | Ultra-fast IPC, memory caching, real-time database compression |

---

## Design Rules

1. **Direct `io` Streaming Protocol Conformance.**
   - Every package provides streaming `Reader<R: io.Reader>: io.Reader` and
     `Writer<W: io.Writer>: io.Writer, io.Closer` adapters.
   - Decompressing an HTTP response or compressing a file streams directly
     through `io.Copy(from: &source, to: &compressor)`.
2. **Zero Native Dependencies.**
   - All Huffman coding, bit manipulation, LZ77 matching, CRC-32, and Adler-32
     algorithms run identically across macOS (ARM64) and Windows (x86-64) without
     linking system C libraries or external dynamic modules.
3. **Strict Checksum & Framing Verification.**
   - `compress/zlib` validates RFC 1950 CMF/FLG header consistency and the 32-bit
     big-endian Adler-32 trailer checksum.
   - `compress/gzip` validates RFC 1952 magic bytes (`0x1F, 0x8B`), method flags,
     trailing 32-bit little-endian IEEE 802.3 CRC-32, and uncompressed size modulo $2^{32}$.
4. **Convenient Buffer APIs.**
   - In addition to streaming readers and writers, each package provides one-shot
     `Compress(_:) -> [uint8]` and `Decompress(_:) throws -> [uint8]` functions for
     in-memory byte arrays.

---

## Quick Start

Run any entry point with:

```bash
vsc run main.vs
```

### 1. In-Memory Compression & Decompression (`gzip`)

```swift
package main

import "compress/gzip"

func main() -> int32 {
    let payload = [uint8]("Vertex: High Performance Native Language".utf8)

    // Compress with automatic RFC 1952 header and CRC-32 trailer
    let compressed = gzip.Compress(payload, name: "example.txt")

    // Decompress and verify
    let decompressed = try! gzip.Decompress(compressed)
    print("Decompressed: \(string(decoding: decompressed, as: UTF8.self))")
    return 0
}
```

### 2. Streaming via `io.Reader` and `io.Writer` (`zlib`)

```swift
package main

import "compress/zlib"
import "io"

func main() -> int32 {
    var output = io.Cursor()
    var writer = zlib.Writer(output)

    try! io.WriteText(&writer, "Streaming data through zlib...")
    try! writer.Close()

    // Read back through streaming Reader
    var reader = zlib.Reader(io.Cursor(writer.Inner.Bytes))
    let extracted = try! io.ReadText(&reader)
    print("Extracted: \(extracted)")
    return 0
}
```

### 3. Ultra-Fast Block Compression (`lz4`)

```swift
package main

import "compress/lz4"

func main() -> int32 {
    let raw = [uint8]("Repeated pattern. Repeated pattern. Repeated pattern.".utf8)

    // Compress block
    let compressed = lz4.Compress(raw)
    print("Compressed from \(raw.count) to \(compressed.count) bytes")

    // Decompress block
    let restored = try! lz4.Decompress(compressed)
    print("Matches: \(restored == raw)")
    return 0
}
```

---

## Technical Specifications

### Gzip Framing (RFC 1952)
```
┌─────────────────────────────────────────────────────────────┐
│ 10-Byte Header (ID1: 0x1F, ID2: 0x8B, CM: 8, FLG, MTIME, OS)│
├─────────────────────────────────────────────────────────────┤
│ Optional FNAME / FCOMMENT null-terminated strings           │
├─────────────────────────────────────────────────────────────┤
│ Raw DEFLATE Compressed Payload                              │
├─────────────────────────────────────────────────────────────┤
│ 8-Byte Trailer (CRC-32 Checksum + Uncompressed Byte Count)  │
└─────────────────────────────────────────────────────────────┘
```

### Zlib Framing (RFC 1950)
```
┌─────────────────────────────────────────────────────────────┐
│ 2-Byte Header (CMF = 0x78, FLG with modulo-31 check)        │
├─────────────────────────────────────────────────────────────┤
│ Raw DEFLATE Compressed Payload                              │
├─────────────────────────────────────────────────────────────┤
│ 4-Byte Trailer (Big-Endian Adler-32 Checksum)               │
└─────────────────────────────────────────────────────────────┘
```

---

## Verification & Testing

Run the test suite via the Vertex compiler:

```bash
# Run the test suite (cmd/check); the Desktop's vs.work finds ../io
vsc run check
```

---

## License

[MIT](LICENSE)
