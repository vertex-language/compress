package flate

// RFC 1951 raw DEFLATE compressor (Deflate).

struct bitWriter {
    var out: [uint8] = []
    var bits: uint32 = 0
    var count: int = 0

    mutating func put(_ v: int, _ n: int) {
        bits |= uint32(v) << uint32(count)
        count += n
        while count >= 8 {
            out.append(uint8(bits & 0xFF))
            bits = bits >> 8
            count -= 8
        }
    }

    mutating func flush() {
        if count > 0 {
            out.append(uint8(bits & 0xFF))
            bits = 0
            count = 0
        }
    }
}

func fixedCodes() -> ([int], [int]) {
    var codes = [int](repeating: 0, count: 288)
    var lens = [int](repeating: 8, count: 288)
    var c = 0x30
    var i = 0
    while i <= 143 {
        codes[i] = reverseBits(c, 8)
        c += 1
        i += 1
    }
    c = 0x190
    while i <= 255 {
        codes[i] = reverseBits(c, 9)
        lens[i] = 9
        c += 1
        i += 1
    }
    c = 0x000
    while i <= 279 {
        codes[i] = reverseBits(c, 7)
        lens[i] = 7
        c += 1
        i += 1
    }
    c = 0x0C0
    while i <= 287 {
        codes[i] = reverseBits(c, 8)
        c += 1
        i += 1
    }
    return (codes, lens)
}

/// Compresses uncompressed data into raw RFC 1951 DEFLATE bytes using fixed Huffman codes.
public func Compress(_ data: [uint8]) -> [uint8] {
    if data.isEmpty {
        var w = bitWriter()
        w.put(1, 1) // BFINAL = 1
        w.put(1, 2) // BTYPE = fixed
        let (codes, lens) = fixedCodes()
        w.put(codes[256], lens[256])
        w.flush()
        return w.out
    }

    var w = bitWriter()
    let (codes, lens) = fixedCodes()
    let lb = lengthBase()
    let le = lengthExtra()
    let db = distBase()
    let de = distExtra()

    var lengthSym = [int](repeating: 0, count: 259)
    var s = 0
    while s < 28 {
        var l = lb[s]
        let end = lb[s + 1]
        while l < end {
            lengthSym[l] = s
            l += 1
        }
        s += 1
    }
    lengthSym[258] = 28

    let hashSize = 1 << 15
    let window = 32768
    let maxChain = 48
    var head = [int](repeating: -1, count: hashSize)
    var prev = [int](repeating: -1, count: window)

    // One fixed-Huffman block
    w.put(1, 1) // BFINAL = 1
    w.put(1, 2) // BTYPE = fixed
    let n = data.count
    var i = 0
    while i < n {
        var bestLen = 0
        var bestDist = 0
        if i + 2 < n {
            let h = ((int(data[i]) << 10) ^ (int(data[i + 1]) << 5) ^ int(data[i + 2])) & (hashSize - 1)
            var cand = head[h]
            var chain = 0
            let maxLen = n - i < 258 ? n - i : 258
            while cand >= 0 && i - cand <= window && chain < maxChain {
                if data[cand + bestLen] == data[i + bestLen] || bestLen == 0 {
                    var l = 0
                    while l < maxLen && data[cand + l] == data[i + l] {
                        l += 1
                    }
                    if l > bestLen {
                        bestLen = l
                        bestDist = i - cand
                        if l == maxLen {
                            break
                        }
                    }
                }
                let next = prev[cand & (window - 1)]
                if next >= cand {
                    break
                }
                cand = next
                chain += 1
            }
            prev[i & (window - 1)] = head[h]
            head[h] = i
        }
        if bestLen >= 3 {
            let ls = lengthSym[bestLen]
            w.put(codes[257 + ls], lens[257 + ls])
            if le[ls] > 0 {
                w.put(bestLen - lb[ls], le[ls])
            }
            var ds = 0
            while ds < 29 && db[ds + 1] <= bestDist {
                ds += 1
            }
            w.put(reverseBits(ds, 5), 5)
            if de[ds] > 0 {
                w.put(bestDist - db[ds], de[ds])
            }
            var k = 1
            while k < bestLen {
                let p = i + k
                if p + 2 < n {
                    let h = ((int(data[p]) << 10) ^ (int(data[p + 1]) << 5) ^ int(data[p + 2])) & (hashSize - 1)
                    prev[p & (window - 1)] = head[h]
                    head[h] = p
                }
                k += 1
            }
            i += bestLen
        } else {
            let b = int(data[i])
            w.put(codes[b], lens[b])
            i += 1
        }
    }
    w.put(codes[256], lens[256])
    w.flush()
    return w.out
}
