package gzip

/// Metadata from the 10-byte RFC 1952 header.
public struct Header: Equatable {
    public var Name: string
    public var Comment: string
    public var ModTime: int64
    public var OS: uint8

    public init(
        name: string = "",
        comment: string = "",
        modTime: int64 = 0,
        os: uint8 = 3 // 3 = Unix
    ) {
        self.Name = name
        self.Comment = comment
        self.ModTime = modTime
        self.OS = os
    }
}
