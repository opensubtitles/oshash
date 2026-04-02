// OpenSubtitles Hash (OSHash) - Kotlin implementation.
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.max
import kotlin.math.min

const val HASH_CHUNK_SIZE = 64 * 1024

fun computeHash(file: File): String {
    val size = file.length()
    val chunkSizeForFile = min(HASH_CHUNK_SIZE.toLong(), size)

    FileInputStream(file).channel.use { fileChannel ->
        val head = computeChunkHash(
            fileChannel.map(FileChannel.MapMode.READ_ONLY, 0, chunkSizeForFile))
        val tail = computeChunkHash(
            fileChannel.map(FileChannel.MapMode.READ_ONLY, max(size - HASH_CHUNK_SIZE, 0), chunkSizeForFile))
        return String.format("%016x", size + head + tail)
    }
}

fun computeChunkHash(buffer: ByteBuffer): Long {
    val longBuffer = buffer.order(ByteOrder.LITTLE_ENDIAN).asLongBuffer()
    var hash = 0L
    while (longBuffer.hasRemaining()) {
        hash += longBuffer.get()
    }
    return hash
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin OshashKt <file>")
        System.exit(1)
    }
    println(computeHash(File(args[0])))
}
