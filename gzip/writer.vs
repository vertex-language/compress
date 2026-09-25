package gzip

import "io"

/// Writer compresses uncompressed bytes into an RFC 1952 gzip stream.
public struct Writer<W: io.Writer>: io.Writer, io.Closer {
    public var Inner: W
    var buffer: [uint8] = []
    var fileName: string
    var closed: bool = false

    public init(_ inner: W, name: string = "") {
        self.Inner = inner
        self.fileName = name
    }

    public mutating func Write(_ bytes: borrowing [uint8]) throws {
        if closed {
            throw GzipError.badHeader("attempted write to closed gzip writer")
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
        let compressed = Compress(buffer, name: fileName)
        try Inner.Write(compressed)
        try Inner.Flush()
        closed = true
    }
}
