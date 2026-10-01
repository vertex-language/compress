# compress/gzip

The gzip format (RFC 1952): a DEFLATE stream with a header and a CRC-32, for HTTP content encoding and `.tar.gz` files.

## Example

```vertex
import "compress/gzip"

let original = [uint8](String(repeating: "vertex ", count: 200).utf8)
let packed = gzip.Compress(original)
let restored = try gzip.Decompress(packed)
print(original.count, packed.count, restored == original)
```

## Types

- **`GzipError`** (enum): Errors encountered while decompressing or validating RFC 1952 gzip streams.
- **`Header`** (struct): Metadata from the 10-byte RFC 1952 header.
- **`Reader`** (struct): Reader decompresses an RFC 1952 gzip stream as it is read: memory stays at the inflater's window however big the stream is.
- **`Writer`** (struct): Writer compresses uncompressed bytes into an RFC 1952 gzip stream.

## Functions

- `func UpdateCRC32(_ crc: uint32, _ data: [uint8]) -> uint32`
- `func ChecksumCRC32(_ data: [uint8]) -> uint32`
- `func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8]`: Decompresses an RFC 1952 gzip stream into raw uncompressed bytes.
- `func Compress(_ data: [uint8], name: string = "") -> [uint8]`: Compresses uncompressed bytes into an RFC 1952 gzip stream.

Part of the [`compress`](https://github.com/vertex-language/compress) repository.
