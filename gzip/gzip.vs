package gzip

import "compress/flate"

/// Decompresses an RFC 1952 gzip stream into raw uncompressed bytes.
public func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8] {
    if data.count < 18 {
        throw GzipError.unexpectedEOF
    }

    if data[0] != 0x1F || data[1] != 0x8B {
        throw GzipError.badHeader("invalid gzip magic identifier")
    }

    let cm = data[2]
    if cm != 8 {
        throw GzipError.unsupportedCompression(cm)
    }

    let flg = data[3]
    var offset = 10

    // Extra field (FEXTRA = 0x04)
    if flg & 0x04 != 0 {
        if offset + 2 > data.count {
            throw GzipError.unexpectedEOF
        }
        let xlen = int(data[offset]) | (int(data[offset + 1]) << 8)
        offset += 2 + xlen
    }

    // Original file name (FNAME = 0x08)
    if flg & 0x08 != 0 {
        while offset < data.count && data[offset] != 0 {
            offset += 1
        }
        offset += 1
    }

    // File comment (FCOMMENT = 0x10)
    if flg & 0x10 != 0 {
        while offset < data.count && data[offset] != 0 {
            offset += 1
        }
        offset += 1
    }

    // Header CRC16 (FHCRC = 0x02)
    if flg & 0x02 != 0 {
        offset += 2
    }

    if offset > data.count - 8 {
        throw GzipError.unexpectedEOF
    }

    let payloadLen = (data.count - 8) - offset
    var payload = [uint8](repeating: 0, count: payloadLen)
    var i = 0
    while i < payloadLen {
        payload[i] = data[offset + i]
        i += 1
    }

    let uncompressed = try flate.Decompress(payload, sizeHint: sizeHint)

    // Read 8-byte trailer: 4-byte CRC32 + 4-byte ISIZE (little-endian)
    let tOffset = data.count - 8
    let b0 = uint32(data[tOffset])
    let b1 = uint32(data[tOffset + 1]) << 8
    let b2 = uint32(data[tOffset + 2]) << 16
    let b3 = uint32(data[tOffset + 3]) << 24
    let expectedCRC = b0 | b1 | b2 | b3

    let s0 = uint32(data[tOffset + 4])
    let s1 = uint32(data[tOffset + 5]) << 8
    let s2 = uint32(data[tOffset + 6]) << 16
    let s3 = uint32(data[tOffset + 7]) << 24
    let expectedSize = s0 | s1 | s2 | s3

    let actualCRC = ChecksumCRC32(uncompressed)
    if actualCRC != expectedCRC {
        throw GzipError.checksumMismatch(expected: expectedCRC, got: actualCRC)
    }

    let actualSize = uint32(uncompressed.count & 0xFFFFFFFF)
    if actualSize != expectedSize {
        throw GzipError.sizeMismatch(expected: expectedSize, got: actualSize)
    }

    return uncompressed
}

/// Compresses uncompressed bytes into an RFC 1952 gzip stream.
public func Compress(_ data: [uint8], name: string = "") -> [uint8] {
    var out: [uint8] = []

    let hasName = !name.isEmpty
    let flg: uint8 = hasName ? 0x08 : 0x00

    // 10-byte header
    out.append(0x1F)
    out.append(0x8B)
    out.append(0x08) // CM = deflate
    out.append(flg)
    out.append(0x00) // MTIME
    out.append(0x00)
    out.append(0x00)
    out.append(0x00)
    out.append(0x02) // XFL = max compression
    out.append(0x03) // OS = Unix

    if hasName {
        for b in name.utf8 {
            out.append(b)
        }
        out.append(0x00)
    }

    let payload = flate.Compress(data)
    for b in payload {
        out.append(b)
    }

    let crc = ChecksumCRC32(data)
    out.append(uint8(crc & 0xFF))
    out.append(uint8((crc >> 8) & 0xFF))
    out.append(uint8((crc >> 16) & 0xFF))
    out.append(uint8((crc >> 24) & 0xFF))

    let size = uint32(data.count & 0xFFFFFFFF)
    out.append(uint8(size & 0xFF))
    out.append(uint8((size >> 8) & 0xFF))
    out.append(uint8((size >> 16) & 0xFF))
    out.append(uint8((size >> 24) & 0xFF))

    return out
}
