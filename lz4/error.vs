package lz4

/// Errors encountered while compressing or decompressing LZ4 blocks.
public enum Lz4Error: Error, Equatable, CustomStringConvertible {
    case unexpectedEOF
    case badData(string)
    case offsetOutOfBounds

    public var description: string {
        switch self {
        case .unexpectedEOF:
            return "unexpected end of lz4 block"
        case .badData(let msg):
            return "corrupt lz4 block: \(msg)"
        case .offsetOutOfBounds:
            return "lz4 match offset points before start of buffer"
        }
    }
}
