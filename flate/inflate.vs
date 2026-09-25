package flate

// RFC 1951 raw DEFLATE decompressor (Inflate).

let fastBits = 9

struct bitReader {
    var data: [uint8]
    var pos: int = 0
    var bits: uint32 = 0
    var count: int = 0

    init(_ data: [uint8], at: int) {
        self.data = data
        self.pos = at
    }

    mutating func need(_ n: int) throws {
        while count < n {
            if pos >= data.count {
                throw FlateError.badData("deflate stream ends early")
            }
            bits |= uint32(data[pos]) << uint32(count)
            pos += 1
            count += 8
        }
    }

    mutating func take(_ n: int) throws -> int {
        if n == 0 {
            return 0
        }
        try need(n)
        let v = int(bits & ((uint32(1) << uint32(n)) - 1))
        bits = bits >> uint32(n)
        count -= n
        return v
    }

    mutating func alignToByte() {
        bits = 0
        count = 0
    }
}

struct huffman {
    var counts: [int]
    var symbols: [int]
    var fast: [int]

    init(_ lengths: [int]) throws {
        counts = [int](repeating: 0, count: 16)
        for l in lengths {
            if l < 16 {
                counts[l] += 1
            }
        }
        counts[0] = 0
        var offs = [int](repeating: 0, count: 16)
        var i = 1
        while i < 15 {
            offs[i + 1] = offs[i] + counts[i]
            i += 1
        }
        symbols = [int](repeating: 0, count: lengths.count)
        var s = 0
        while s < lengths.count {
            if lengths[s] != 0 && lengths[s] < 16 {
                symbols[offs[lengths[s]]] = s
                offs[lengths[s]] += 1
            }
            s += 1
        }
        fast = [int](repeating: -1, count: 1 << fastBits)
        var code = 0
        var index = 0
        var len = 1
        while len <= fastBits {
            var n = 0
            while n < counts[len] {
                let sym = symbols[index]
                let rev = reverseBits(code, len)
                var fill = rev
                while fill < (1 << fastBits) {
                    fast[fill] = (sym << 4) | len
                    fill += 1 << len
                }
                code += 1
                index += 1
                n += 1
            }
            code = code << 1
            len += 1
        }
    }

    func decode(_ br: inout bitReader) throws -> int {
        while br.count < fastBits && br.pos < br.data.count {
            br.bits |= uint32(br.data[br.pos]) << uint32(br.count)
            br.pos += 1
            br.count += 8
        }
        let e = fast[int(br.bits & uint32((1 << fastBits) - 1))]
        if e >= 0 && (e & 15) <= br.count {
            let l = e & 15
            br.bits = br.bits >> uint32(l)
            br.count -= l
            return e >> 4
        }
        var code = 0
        var first = 0
        var index = 0
        var len = 1
        while len <= 15 {
            code |= try br.take(1)
            let count = counts[len]
            if code - count < first {
                return symbols[index + (code - first)]
            }
            index += count
            first += count
            first = first << 1
            code = code << 1
            len += 1
        }
        throw FlateError.badHuffmanCode
    }
}

func reverseBits(_ v: int, _ n: int) -> int {
    var r = 0
    var x = v
    var i = 0
    while i < n {
        r = (r << 1) | (x & 1)
        x = x >> 1
        i += 1
    }
    return r
}

func lengthBase() -> [int] {
    return [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
            35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
}

func lengthExtra() -> [int] {
    return [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
            3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
}

func distBase() -> [int] {
    return [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
            257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
            8193, 12289, 16385, 24577]
}

func distExtra() -> [int] {
    return [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
            7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
}

func fixedLiteralLengths() -> [int] {
    var lens = [int](repeating: 8, count: 288)
    var i = 144
    while i < 256 {
        lens[i] = 9
        i += 1
    }
    while i < 280 {
        lens[i] = 7
        i += 1
    }
    return lens
}

/// Decompresses raw RFC 1951 DEFLATE bytes into uncompressed data.
public func Decompress(_ data: [uint8], sizeHint: int = 0) throws -> [uint8] {
    var out: [uint8] = []
    if sizeHint > 0 {
        out = [uint8](repeating: 0, count: sizeHint)
    }
    var n = 0
    var br = bitReader(data, at: 0)
    let lb = lengthBase()
    let le = lengthExtra()
    let db = distBase()
    let de = distExtra()
    let fixedLit = try huffman(fixedLiteralLengths())
    let fixedDist = try huffman([int](repeating: 5, count: 30))

    var final = false
    while !final {
        final = try br.take(1) == 1
        let type = try br.take(2)
        if type == 0 {
            br.alignToByte()
            if br.pos + 4 > data.count {
                throw FlateError.badData("stored block header truncated")
            }
            let len = int(data[br.pos]) | (int(data[br.pos + 1]) << 8)
            let nlen = int(data[br.pos + 2]) | (int(data[br.pos + 3]) << 8)
            if len != (~nlen & 0xFFFF) {
                throw FlateError.badData("stored block length check mismatch")
            }
            br.pos += 4
            if br.pos + len > data.count {
                throw FlateError.badData("stored block payload truncated")
            }
            var i = 0
            while i < len {
                if n >= out.count {
                    out.append(data[br.pos + i])
                } else {
                    out[n] = data[br.pos + i]
                }
                n += 1
                i += 1
            }
            br.pos += len
            continue
        }
        if type == 3 {
            throw FlateError.reservedBlockType
        }
        var lit = fixedLit
        var dist = fixedDist
        if type == 2 {
            let hlit = try br.take(5) + 257
            let hdist = try br.take(5) + 1
            let hclen = try br.take(4) + 4
            let order: [int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
            var clens = [int](repeating: 0, count: 19)
            var i = 0
            while i < hclen {
                clens[order[i]] = try br.take(3)
                i += 1
            }
            let ch = try huffman(clens)
            var lengths = [int](repeating: 0, count: hlit + hdist)
            var idx = 0
            while idx < hlit + hdist {
                let sym = try ch.decode(&br)
                if sym < 16 {
                    lengths[idx] = sym
                    idx += 1
                } else if sym == 16 {
                    if idx == 0 {
                        throw FlateError.badData("repeat code before any length")
                    }
                    let rep = try br.take(2) + 3
                    let v = lengths[idx - 1]
                    var k = 0
                    while k < rep && idx < hlit + hdist {
                        lengths[idx] = v
                        idx += 1
                        k += 1
                    }
                } else if sym == 17 {
                    let rep = try br.take(3) + 3
                    var k = 0
                    while k < rep && idx < hlit + hdist {
                        lengths[idx] = 0
                        idx += 1
                        k += 1
                    }
                } else if sym == 18 {
                    let rep = try br.take(7) + 11
                    var k = 0
                    while k < rep && idx < hlit + hdist {
                        lengths[idx] = 0
                        idx += 1
                        k += 1
                    }
                }
            }
            var litLens = [int](repeating: 0, count: hlit)
            var k = 0
            while k < hlit {
                litLens[k] = lengths[k]
                k += 1
            }
            var distLens = [int](repeating: 0, count: hdist)
            k = 0
            while k < hdist {
                distLens[k] = lengths[hlit + k]
                k += 1
            }
            lit = try huffman(litLens)
            dist = try huffman(distLens)
        }

        while true {
            let sym = try lit.decode(&br)
            if sym < 256 {
                if n >= out.count {
                    out.append(uint8(sym))
                } else {
                    out[n] = uint8(sym)
                }
                n += 1
            } else if sym == 256 {
                break
            } else {
                let li = sym - 257
                if li >= lb.count {
                    throw FlateError.badData("length code out of bounds")
                }
                let length = lb[li] + (try br.take(le[li]))
                let di = try dist.decode(&br)
                if di >= db.count {
                    throw FlateError.badData("distance code out of bounds")
                }
                let distance = db[di] + (try br.take(de[di]))
                if distance > n {
                    throw FlateError.distanceOutOfBounds
                }
                var p = n - distance
                var count = length
                while count > 0 {
                    let b = out[p]
                    if n >= out.count {
                        out.append(b)
                    } else {
                        out[n] = b
                    }
                    n += 1
                    p += 1
                    count -= 1
                }
            }
        }
    }

    if n < out.count {
        out = Array(out[0..<n])
    }
    return out
}
