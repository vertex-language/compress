# compress/flate

Raw DEFLATE (RFC 1951) encoding and decoding: the foundation under zlib and gzip, and the compression ZIP archives use.

```vertex
import "compress/flate"
```

## Types

- **`FlateError`** (enum): Errors encountered while decompressing or compressing RFC 1951 raw DEFLATE streams.
- **`Reader`** (struct): Reader decompresses an RFC 1951 raw DEFLATE stream as it is read, holding a 32 KiB window rather than the whole output: see Inflater.
- **`Decoder`** (class): Decoder decompresses raw DEFLATE fed to it a piece at a time, keeping only the last 32 KiB of output -- the most a back-reference reaches -- so memory stays the same however long the stream is.
- **`Inflater`** (struct): Inflater decompresses a raw DEFLATE stream as it is read from `Inner`, with a Decoder's constant memory.
- **`Writer`** (struct): Writer compresses uncompressed bytes into an RFC 1951 raw DEFLATE stream.

## Functions

- `func Compress(_ data: [uint8]) -> [uint8]`: Compresses uncompressed data into raw RFC 1951 DEFLATE bytes using fixed Huffman codes.
- `func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8]`: Decompresses raw RFC 1951 DEFLATE bytes into uncompressed data.

Part of the [`compress`](https://github.com/vertex-language/compress) repository.
