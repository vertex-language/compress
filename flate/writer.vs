package flate

import "io"

/// Writer compresses uncompressed bytes into an RFC 1951 raw DEFLATE stream.
public struct Writer<W: io.Writer>: io.Writer, io.Closer {
    public var Inner: W
    var buffer: [uint8] = []
    var closed: bool = false

    public init(_ inner: W) {
        self.Inner = inner
    }

    public mutating func Write(_ bytes: borrowing [uint8]) throws {
        if closed {
            throw FlateError.badData("attempted write to closed flate writer")
        }
        for b in bytes {
            buffer.append(b)
        }
    }

    public mutating func Flush() throws {
        try Inner.Flush()
    }

    public mutating func Close() throws {
        if closed {
            return
        }
        let compressed = Compress(buffer)
        try Inner.Write(compressed)
        try Inner.Flush()
        closed = true
    }
}
