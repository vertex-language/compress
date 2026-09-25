package gzip

let IEEE: uint32 = 0xEDB88320

func makeTable() -> [uint32] {
    var tab = [uint32](repeating: 0, count: 256)
    var i: uint32 = 0
    while i < 256 {
        var c = i
        var j = 0
        while j < 8 {
            if (c & 1) != 0 {
                c = IEEE ^ (c >> 1)
            } else {
                c = c >> 1
            }
            j += 1
        }
        tab[int(i)] = c
        i += 1
    }
    return tab
}

let tableIEEE: [uint32] = makeTable()

public func UpdateCRC32(_ crc: uint32, _ data: [uint8]) -> uint32 {
    var c = ~crc
    var i = 0
    while i < data.count {
        let idx = int((c ^ uint32(data[i])) & 0xFF)
        c = tableIEEE[idx] ^ (c >> 8)
        i += 1
    }
    return ~c
}

public func ChecksumCRC32(_ data: [uint8]) -> uint32 {
    return UpdateCRC32(0, data)
}
