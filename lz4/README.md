# compress/lz4

LZ4 block compression: very fast, for inter-process messages, memory caches, and real-time databases.

```vertex
import "compress/lz4"
```

## Types

- **`Lz4Error`** (enum): Errors encountered while compressing or decompressing LZ4 blocks.

## Functions

- `func Decompress(_ data: [uint8]) throws -> [uint8]`: Decompresses an LZ4 block with a 4-byte uncompressed size prefix.
- `func DecompressBlock(_ data: [uint8], uncompressedSize: int) throws -> [uint8]`: Decompresses a raw LZ4 block where the uncompressed size is known.
- `func Compress(_ data: [uint8]) -> [uint8]`: Compresses an uncompressed byte buffer using LZ4 block compression, prepending a 4-byte size header.
- `func CompressBlock(_ data: [uint8]) -> [uint8]`: Compresses raw bytes into an LZ4 block.

Part of the [`compress`](https://github.com/vertex-language/compress) repository.
