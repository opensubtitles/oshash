#!/usr/bin/env groovy
// OpenSubtitles Hash (OSHash) - Groovy implementation.
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.nio.channels.FileChannel.MapMode

HASH_CHUNK_SIZE = 64 * 1024

def computeHashForChunk(buffer) {
    def longBuffer = buffer.order(ByteOrder.LITTLE_ENDIAN).asLongBuffer()
    long hash = 0
    while (longBuffer.hasRemaining()) {
        hash += longBuffer.get()
    }
    return hash
}

def computeHash(file) {
    def size = file.length()
    def chunkSizeForFile = Math.min(HASH_CHUNK_SIZE, size)
    def fileChannel = new FileInputStream(file).getChannel()

    try {
        def head = computeHashForChunk(
            fileChannel.map(MapMode.READ_ONLY, 0, chunkSizeForFile))
        def tail = computeHashForChunk(
            fileChannel.map(MapMode.READ_ONLY, Math.max(size - HASH_CHUNK_SIZE, 0), chunkSizeForFile))
        return String.format("%016x", size + head + tail)
    } finally {
        fileChannel.close()
    }
}

if (args.length < 1) {
    System.err.println("Usage: groovy oshash.groovy <file>")
    System.exit(1)
}

println(computeHash(new File(args[0])))
