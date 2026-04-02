// OpenSubtitles Hash (OSHash) - Swift implementation.
// Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)
import Foundation

let chunkSize = 65536

func computeHash(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let fileHandle = try! FileHandle(forReadingFrom: url)
    defer { fileHandle.closeFile() }

    fileHandle.seekToEndOfFile()
    let fileSize = fileHandle.offsetInFile
    fileHandle.seek(toFileOffset: 0)

    var hash: UInt64 = fileSize

    // Hash first 64KB
    let headData = fileHandle.readData(ofLength: chunkSize)
    headData.withUnsafeBytes { raw in
        let longs = raw.bindMemory(to: UInt64.self)
        for val in longs { hash &+= UInt64(littleEndian: val) }
    }

    // Hash last 64KB
    fileHandle.seek(toFileOffset: max(0, fileSize - UInt64(chunkSize)))
    let tailData = fileHandle.readData(ofLength: chunkSize)
    tailData.withUnsafeBytes { raw in
        let longs = raw.bindMemory(to: UInt64.self)
        for val in longs { hash &+= UInt64(littleEndian: val) }
    }

    return String(format: "%016lx", hash)
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: oshash <file>\n", stderr)
    exit(1)
}
print(computeHash(CommandLine.arguments[1]))
