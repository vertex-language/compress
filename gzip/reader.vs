package gzip

import "io"

/// Reader provides streaming decompression of an RFC 1952 gzip stream.
public struct Reader<R: io.Reader>: io.Reader {
    public var Inner: R
    var decompressed: [uint8]?
    var position: int = 0

    public init(_ inner: R) {
        self.Inner = inner
    }

    public mutating func Read(into buffer: inout [uint8]) throws -> int {
        if decompressed == nil {
            let compressed = try io.ReadToEnd(&Inner)
            let out = try Decompress(compressed)
            decompressed = out
            position = 0
        }

        guard let data = decompressed else {
            return 0
        }

        if position >= data.count || buffer.isEmpty {
            return 0
        }

        var n = 0
        while n < buffer.count && position < data.count {
            buffer[n] = data[position]
            n += 1
            position += 1
        }
        return n
    }
}
