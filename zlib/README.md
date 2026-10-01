# compress/zlib

The zlib format (RFC 1950): a DEFLATE stream with a header and an Adler-32 checksum, as PNG images, Git objects, and PDF streams use it.

```vertex
import "compress/zlib"
```

## Types

- **`ZlibError`** (enum): Errors encountered while processing RFC 1950 zlib streams.
- **`Reader`** (struct): Reader decompresses an RFC 1950 zlib stream as it is read, holding the inflater's 32 KiB window rather than the whole output.
- **`Writer`** (struct): Writer compresses uncompressed bytes into an RFC 1950 zlib stream.

## Functions

- `func Adler32(_ data: [uint8]) -> uint32`: Computes the RFC 1950 Adler-32 checksum of data.
- `func UpdateAdler32(_ initial: uint32, _ data: [uint8]) -> uint32`: Updates a running Adler-32 checksum with additional bytes.
- `func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8]`: Decompresses an RFC 1950 zlib stream into raw uncompressed bytes.
- `func Compress(_ data: [uint8]) -> [uint8]`: Compresses uncompressed bytes into an RFC 1950 zlib stream.

Part of the [`compress`](https://github.com/vertex-language/compress) repository.
