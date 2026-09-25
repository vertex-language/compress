package zlib

/// Errors encountered while processing RFC 1950 zlib streams.
public enum ZlibError: Error, Equatable, CustomStringConvertible {
    case unexpectedEOF
    case badHeader(string)
    case unsupportedMethod(int)
    case presetDictionaryUnsupported
    case checksumMismatch(expected: uint32, got: uint32)

    public var description: string {
        switch self {
        case .unexpectedEOF:
            return "unexpected end of zlib stream"
        case .badHeader(let msg):
            return "corrupt zlib header: \(msg)"
        case .unsupportedMethod(let m):
            return "unsupported zlib compression method: \(m)"
        case .presetDictionaryUnsupported:
            return "zlib preset dictionary is not supported"
        case .checksumMismatch(let exp, let got):
            return "adler32 checksum mismatch: expected \(exp), got \(got)"
        }
    }
}
