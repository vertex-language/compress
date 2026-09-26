// compress test suite: comprehensive checks for flate, zlib, gzip, and lz4.
package main

import (
    "compress/flate"
    "compress/gzip"
    "compress/lz4"
    "compress/zlib"
    "io"
)

var failures: int32 = 0

func check(_ ok: bool, _ what: string) {
    if ok {
        print("ok    \(what)")
    } else {
        print("FAIL  \(what)")
        failures += 1
    }
}

// ---------------------------------------------------------------------------
// FLATE tests
// ---------------------------------------------------------------------------

func testFlate() {
    // Empty data
    let empty = flate.Compress([])
    check(try! flate.Decompress(empty).isEmpty, "flate empty round-trip")

    // Simple string
    let msg = [uint8]("Hello Vertex DEFLATE!".utf8)
    let comp = flate.Compress(msg)
    check(try! flate.Decompress(comp) == msg, "flate simple string round-trip")

    // Repetitive text
    var large: [uint8] = []
    for _ in 0..<50 {
        for b in "Repeated payload for compression testing. ".utf8 {
            large.append(b)
        }
    }
    let compLarge = flate.Compress(large)
    check(compLarge.count < large.count, "flate compresses repetitive data")
    check(try! flate.Decompress(compLarge) == large, "flate decompresses repetitive data")

    // Streaming Writer and Reader
    do {
        var w = flate.Writer(io.Cursor())
        try io.WriteText(&w, "Streaming through flate.Writer...")
        try w.Close()

        var r = flate.Reader(io.Cursor(w.Inner.Bytes))
        let text = try io.ReadText(&r)
        check(text == "Streaming through flate.Writer...", "flate streaming Reader and Writer")
    } catch {
        check(false, "flate streaming threw: \(error)")
    }
}

// ---------------------------------------------------------------------------
// ZLIB tests
// ---------------------------------------------------------------------------

func testZlib() {
    // Adler-32 test vectors:
    // Empty buffer adler32 is 1
    check(zlib.Adler32([]) == 1, "zlib adler32 empty is 1")
    // "123456789" adler32 is 0x091E01DE (152961502)
    let vec = [uint8]("123456789".utf8)
    check(zlib.Adler32(vec) == 0x091E01DE, "zlib adler32 test vector (0x091E01DE)")

    // Round-trip
    let data = [uint8]("Zlib payload with CMF/FLG and Adler-32 trailer.".utf8)
    let compressed = zlib.Compress(data)
    check(compressed.count >= 6, "zlib stream has header and trailer")
    check(compressed[0] == 0x78 && compressed[1] == 0x01, "zlib header CMF and FLG")

    let decompressed = try! zlib.Decompress(compressed)
    check(decompressed == data, "zlib decompress round-trip")

    // Streaming
    do {
        var w = zlib.Writer(io.Cursor())
        try io.WriteText(&w, "Streaming zlib content")
        try w.Close()

        var r = zlib.Reader(io.Cursor(w.Inner.Bytes))
        let got = try io.ReadText(&r)
        check(got == "Streaming zlib content", "zlib streaming Reader and Writer")
    } catch {
        check(false, "zlib streaming threw: \(error)")
    }

    // Corrupted Adler-32
    var corrupt = compressed
    let last = corrupt.count - 1
    corrupt[last] = corrupt[last] ^ 0xFF
    var threwChecksum = false
    do {
        _ = try zlib.Decompress(corrupt)
    } catch ZlibError.checksumMismatch {
        threwChecksum = true
    } catch {}
    check(threwChecksum, "zlib throws checksumMismatch on corrupted adler32")

    // Corrupted header
    var corruptHeader = compressed
    corruptHeader[1] = corruptHeader[1] ^ 0xFF
    var threwHeader = false
    do {
        _ = try zlib.Decompress(corruptHeader)
    } catch ZlibError.badHeader {
        threwHeader = true
    } catch {}
    check(threwHeader, "zlib throws badHeader on corrupted header")
}

// ---------------------------------------------------------------------------
// GZIP tests
// ---------------------------------------------------------------------------

func testGzip() {
    let payload = [uint8]("Gzip standard RFC 1952 payload testing.".utf8)

    // In-memory with filename
    let compressed = gzip.Compress(payload, name: "data.txt")
    check(compressed[0] == 0x1F && compressed[1] == 0x8B, "gzip magic identifier 0x1F, 0x8B")
    check(compressed[2] == 0x08, "gzip compression method 8 (deflate)")

    let decompressed = try! gzip.Decompress(compressed)
    check(decompressed == payload, "gzip decompress round-trip with filename")

    // In-memory without filename
    let compNoName = gzip.Compress(payload)
    let decompNoName = try! gzip.Decompress(compNoName)
    check(decompNoName == payload, "gzip decompress round-trip without filename")

    // Streaming Reader and Writer
    do {
        var w = gzip.Writer(io.Cursor(), name: "stream.log")
        try io.WriteText(&w, "Line 1: Log entry\nLine 2: Log entry\n")
        try w.Close()

        var r = gzip.Reader(io.Cursor(w.Inner.Bytes))
        let text = try io.ReadText(&r)
        check(text == "Line 1: Log entry\nLine 2: Log entry\n", "gzip streaming Reader and Writer")
    } catch {
        check(false, "gzip streaming threw: \(error)")
    }

    // Corrupted CRC-32
    var corruptCRC = compressed
    let crcPos = corruptCRC.count - 8
    corruptCRC[crcPos] = corruptCRC[crcPos] ^ 0xFF
    var threwCRC = false
    do {
        _ = try gzip.Decompress(corruptCRC)
    } catch GzipError.checksumMismatch {
        threwCRC = true
    } catch {}
    check(threwCRC, "gzip throws checksumMismatch on corrupted crc")

    // Corrupted ISIZE
    var corruptSize = compressed
    let szPos = corruptSize.count - 4
    corruptSize[szPos] = corruptSize[szPos] ^ 0xFF
    var threwSize = false
    do {
        _ = try gzip.Decompress(corruptSize)
    } catch GzipError.sizeMismatch {
        threwSize = true
    } catch {}
    check(threwSize, "gzip throws sizeMismatch on corrupted size trailer")
}

// ---------------------------------------------------------------------------
// LZ4 tests
// ---------------------------------------------------------------------------

func testLz4() {
    // Empty
    let emptyComp = lz4.Compress([])
    check(try! lz4.Decompress(emptyComp).isEmpty, "lz4 empty round-trip")

    // Simple string
    let str = [uint8]("LZ4 ultra-fast block compression testing!".utf8)
    let comp = lz4.Compress(str)
    check(try! lz4.Decompress(comp) == str, "lz4 simple string round-trip")

    // Repetitive text (must compress significantly)
    var large: [uint8] = []
    for _ in 0..<100 {
        for b in "ABCDEF1234567890ABCDEF1234567890".utf8 {
            large.append(b)
        }
    }
    let compLarge = lz4.Compress(large)
    check(compLarge.count < large.count, "lz4 compresses repetitive data")
    check(try! lz4.Decompress(compLarge) == large, "lz4 decompresses repetitive data correctly")

    // Error handling: offset out of bounds
    // Token with 0 literals and match length, followed by offset 0
    let badBlock: [uint8] = [
        4, 0, 0, 0, // uncompressed size 4
        0x00,       // 0 literals, 0 extra match (len 4)
        0x00, 0x00  // offset 0 (invalid)
    ]
    var threwOffset = false
    do {
        _ = try lz4.Decompress(badBlock)
    } catch Lz4Error.offsetOutOfBounds {
        threwOffset = true
    } catch {}
    check(threwOffset, "lz4 throws offsetOutOfBounds on invalid back-reference")
}

// ---------------------------------------------------------------------------
// Main runner
// ---------------------------------------------------------------------------

func main() -> int32 {
    print("Running FLATE tests...")
    testFlate()

    print("Running ZLIB tests...")
    testZlib()

    print("Running GZIP tests...")
    testGzip()

    print("Running LZ4 tests...")
    testLz4()

    if failures > 0 {
        print("\(failures) checks failed")
        return 1
    }
    print("all passed")
    return 0
}
