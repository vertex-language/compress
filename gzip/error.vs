package gzip

/// Errors encountered while decompressing or validating RFC 1952 gzip streams.
public enum GzipError: Error, Equatable, CustomStringConvertible {
    case unexpectedEOF
    case badHeader(string)
    case unsupportedCompression(uint8)
    case checksumMismatch(expected: uint32, got: uint32)
    case sizeMismatch(expected: uint32, got: uint32)

    public var description: string {
        switch self {
        case .unexpectedEOF:
            return "unexpected end of gzip stream"
        case .badHeader(let msg):
            return "corrupt gzip header: \(msg)"
        case .unsupportedCompression(let c):
            return "unsupported gzip compression method: \(c)"
        case .checksumMismatch(let exp, let got):
            return "gzip crc32 mismatch: expected \(exp), got \(got)"
        case .sizeMismatch(let exp, let got):
            return "gzip size mismatch: expected \(exp), got \(got)"
        }
    }
}
