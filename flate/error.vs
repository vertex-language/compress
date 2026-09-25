package flate

/// Errors encountered while decompressing or compressing RFC 1951 raw DEFLATE streams.
public enum FlateError: Error, Equatable, CustomStringConvertible {
    case unexpectedEOF
    case badData(string)
    case reservedBlockType
    case badHuffmanCode
    case distanceOutOfBounds

    public var description: string {
        switch self {
        case .unexpectedEOF:
            return "unexpected end of deflate stream"
        case .badData(let msg):
            return "corrupt deflate stream: \(msg)"
        case .reservedBlockType:
            return "reserved deflate block type (3)"
        case .badHuffmanCode:
            return "invalid huffman code in deflate stream"
        case .distanceOutOfBounds:
            return "deflate back-reference distance exceeds buffer"
        }
    }
}
