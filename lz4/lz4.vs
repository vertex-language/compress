package lz4

/// Decompresses an LZ4 block with a 4-byte uncompressed size prefix.
public func Decompress(_ data: [uint8]) throws -> [uint8] {
    if data.count < 4 {
        throw Lz4Error.unexpectedEOF
    }
    let u0 = int(data[0])
    let u1 = int(data[1]) << 8
    let u2 = int(data[2]) << 16
    let u3 = int(data[3]) << 24
    let targetSize = u0 | u1 | u2 | u3

    var block = [uint8](repeating: 0, count: data.count - 4)
    var i = 0
    while i < block.count {
        block[i] = data[4 + i]
        i += 1
    }

    return try DecompressBlock(block, uncompressedSize: targetSize)
}

/// Decompresses a raw LZ4 block where the uncompressed size is known.
public func DecompressBlock(_ data: [uint8], uncompressedSize: int) throws -> [uint8] {
    var out = [uint8]()
    if uncompressedSize > 0 {
        out = [uint8](repeating: 0, count: uncompressedSize)
    }
    var outPos = 0
    var inPos = 0
    let n = data.count

    while inPos < n {
        let token = int(data[inPos])
        inPos += 1

        var litLen = token >> 4
        if litLen == 15 {
            while inPos < n {
                let s = int(data[inPos])
                inPos += 1
                litLen += s
                if s < 255 {
                    break
                }
            }
        }

        if inPos + litLen > n {
            throw Lz4Error.unexpectedEOF
        }
        var i = 0
        while i < litLen {
            if outPos >= out.count {
                out.append(data[inPos + i])
            } else {
                out[outPos] = data[inPos + i]
            }
            outPos += 1
            i += 1
        }
        inPos += litLen

        if inPos >= n {
            break
        }

        if inPos + 2 > n {
            throw Lz4Error.unexpectedEOF
        }
        let offset = int(data[inPos]) | (int(data[inPos + 1]) << 8)
        inPos += 2
        if offset == 0 || offset > outPos {
            throw Lz4Error.offsetOutOfBounds
        }

        var matchLen = (token & 0x0F) + 4
        if matchLen == 19 {
            while inPos < n {
                let s = int(data[inPos])
                inPos += 1
                matchLen += s
                if s < 255 {
                    break
                }
            }
        }

        var p = outPos - offset
        var m = 0
        while m < matchLen {
            let b = out[p]
            if outPos >= out.count {
                out.append(b)
            } else {
                out[outPos] = b
            }
            outPos += 1
            p += 1
            m += 1
        }
    }

    if outPos < out.count {
        out = Array(out[0..<outPos])
    }
    return out
}

/// Compresses an uncompressed byte buffer using LZ4 block compression, prepending a 4-byte size header.
public func Compress(_ data: [uint8]) -> [uint8] {
    let rawBlock = CompressBlock(data)
    var out = [uint8](repeating: 0, count: 4 + rawBlock.count)
    let sz = data.count
    out[0] = uint8(sz & 0xFF)
    out[1] = uint8((sz >> 8) & 0xFF)
    out[2] = uint8((sz >> 16) & 0xFF)
    out[3] = uint8((sz >> 24) & 0xFF)

    var i = 0
    while i < rawBlock.count {
        out[4 + i] = rawBlock[i]
        i += 1
    }
    return out
}

/// Compresses raw bytes into an LZ4 block.
public func CompressBlock(_ data: [uint8]) -> [uint8] {
    let n = data.count
    if n == 0 {
        return []
    }

    var out = [uint8]()
    let tableSize = 4096
    var table = [int](repeating: -1, count: tableSize)

    var anchor = 0
    var i = 0

    while i + 4 <= n {
        let b0 = int(data[i])
        let b1 = int(data[i + 1])
        let b2 = int(data[i + 2])
        let b3 = int(data[i + 3])
        let h = ((b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) & 0x7FFFFFFF) % tableSize

        let ref = table[h]
        table[h] = i

        if ref >= 0 && (i - ref) <= 65535 && (i - ref) > 0 {
            if data[ref] == data[i] && data[ref + 1] == data[i + 1] &&
               data[ref + 2] == data[i + 2] && data[ref + 3] == data[i + 3] {

                var matchLen = 4
                while (i + matchLen < n) && (data[ref + matchLen] == data[i + matchLen]) {
                    matchLen += 1
                }

                let litLen = i - anchor
                let offset = i - ref

                let tokenLit = litLen >= 15 ? 15 : litLen
                let tokenMatch = (matchLen - 4) >= 15 ? 15 : (matchLen - 4)
                out.append(uint8((tokenLit << 4) | tokenMatch))

                if litLen >= 15 {
                    var remainingLit = litLen - 15
                    while remainingLit >= 255 {
                        out.append(255)
                        remainingLit -= 255
                    }
                    out.append(uint8(remainingLit))
                }

                var k = 0
                while k < litLen {
                    out.append(data[anchor + k])
                    k += 1
                }

                out.append(uint8(offset & 0xFF))
                out.append(uint8((offset >> 8) & 0xFF))

                if (matchLen - 4) >= 15 {
                    var remainingMatch = (matchLen - 4) - 15
                    while remainingMatch >= 255 {
                        out.append(255)
                        remainingMatch -= 255
                    }
                    out.append(uint8(remainingMatch))
                }

                i += matchLen
                anchor = i
                continue
            }
        }
        i += 1
    }

    let lastLit = n - anchor
    if lastLit > 0 {
        let tokenLit = lastLit >= 15 ? 15 : lastLit
        out.append(uint8(tokenLit << 4))
        if lastLit >= 15 {
            var rem = lastLit - 15
            while rem >= 255 {
                out.append(255)
                rem -= 255
            }
            out.append(uint8(rem))
        }
        var k = 0
        while k < lastLit {
            out.append(data[anchor + k])
            k += 1
        }
    }

    return out
}
