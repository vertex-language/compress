package zlib

/// Computes the RFC 1950 Adler-32 checksum of data.
public func Adler32(_ data: [uint8]) -> uint32 {
    return UpdateAdler32(1, data)
}

/// Updates a running Adler-32 checksum with additional bytes.
public func UpdateAdler32(_ initial: uint32, _ data: [uint8]) -> uint32 {
    var a: uint32 = initial & 0xFFFF
    var b: uint32 = (initial >> 16) & 0xFFFF
    var i = 0
    let n = data.count
    while i < n {
        var end = i + 5552
        if end > n {
            end = n
        }
        while i < end {
            a += uint32(data[i])
            b += a
            i += 1
        }
        a = a % 65521
        b = b % 65521
    }
    return (b << 16) | a
}
