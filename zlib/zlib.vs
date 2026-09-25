package zlib

import "compress/flate"

/// Decompresses an RFC 1950 zlib stream into raw uncompressed bytes.
public func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8] {
    if data.count < 6 {
        throw ZlibError.unexpectedEOF
    }

    let cmf = int(data[0])
    let flg = int(data[1])

    if (cmf * 256 + flg) % 31 != 0 {
        throw ZlibError.badHeader("header check mismatch")
    }

    let method = cmf & 0x0F
    if method != 8 {
        throw ZlibError.unsupportedMethod(method)
    }

    if flg & 0x20 != 0 {
        throw ZlibError.presetDictionaryUnsupported
    }

    let payloadLen = data.count - 6
    var payload = [uint8](repeating: 0, count: payloadLen)
    var i = 0
    while i < payloadLen {
        payload[i] = data[2 + i]
        i += 1
    }

    let uncompressed = try flate.Decompress(payload, sizeHint: sizeHint)

    let n = data.count
    let b0 = uint32(data[n - 4]) << 24
    let b1 = uint32(data[n - 3]) << 16
    let b2 = uint32(data[n - 2]) << 8
    let b3 = uint32(data[n - 1])
    let expectedAdler = b0 | b1 | b2 | b3

    let actualAdler = Adler32(uncompressed)
    if actualAdler != expectedAdler {
        throw ZlibError.checksumMismatch(expected: expectedAdler, got: actualAdler)
    }

    return uncompressed
}

/// Compresses uncompressed bytes into an RFC 1950 zlib stream.
public func Compress(_ data: [uint8]) -> [uint8] {
    var out: [uint8] = []

    // 2-byte header: CMF = 0x78 (deflate, 32K window), FLG = 0x01
    out.append(0x78)
    out.append(0x01)

    let payload = flate.Compress(data)
    for b in payload {
        out.append(b)
    }

    let a = Adler32(data)
    out.append(uint8((a >> 24) & 0xFF))
    out.append(uint8((a >> 16) & 0xFF))
    out.append(uint8((a >> 8) & 0xFF))
    out.append(uint8(a & 0xFF))

    return out
}
